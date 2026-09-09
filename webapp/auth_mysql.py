from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
import threading
import time
from datetime import datetime, timedelta
from http.cookies import SimpleCookie
from pathlib import Path
from typing import Any

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - dependency error is reported by auth_status
    load_dotenv = None

if load_dotenv is not None:
    load_dotenv(Path(__file__).resolve().parent / ".env")

try:
    import pymysql
    from pymysql.cursors import DictCursor
except ImportError:  # pragma: no cover - dependency error is reported at runtime
    pymysql = None
    DictCursor = None


COOKIE_NAME = "research_platform_session"
SESSION_DAYS = max(1, min(30, int(os.environ.get("AUTH_SESSION_DAYS", "7"))))
MAX_JSON_BYTES = 64 * 1024
SCRYPT_N = 2**14
SCRYPT_R = 8
SCRYPT_P = 5
SCRYPT_LENGTH = 64
EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
DB_NAME_PATTERN = re.compile(r"^[A-Za-z0-9_]+$")

_rate_lock = threading.Lock()
_rate_attempts: dict[str, list[float]] = {}


class AuthError(Exception):
    status = 400
    code = "auth_error"


class AuthUnavailable(AuthError):
    status = 503
    code = "database_unavailable"


class AuthValidationError(AuthError):
    status = 422
    code = "validation_error"


class AuthConflict(AuthError):
    status = 409
    code = "account_exists"


class InvalidCredentials(AuthError):
    status = 401
    code = "invalid_credentials"


class AuthRateLimited(AuthError):
    status = 429
    code = "too_many_attempts"


def _database_name() -> str:
    name = os.environ.get("MYSQL_DATABASE", "research_platform").strip()
    if not DB_NAME_PATTERN.fullmatch(name):
        raise AuthUnavailable("MYSQL_DATABASE 只能包含字母、数字和下划线。")
    return name


def _connection_kwargs(include_database: bool = True) -> dict[str, Any]:
    if pymysql is None or DictCursor is None:
        raise AuthUnavailable("缺少 PyMySQL，请先安装项目依赖。")
    config: dict[str, Any] = {
        "host": os.environ.get("MYSQL_HOST", "127.0.0.1"),
        "port": int(os.environ.get("MYSQL_PORT", "3306")),
        "user": os.environ.get("MYSQL_USER", "root"),
        "password": os.environ.get("MYSQL_PASSWORD", ""),
        "charset": "utf8mb4",
        "cursorclass": DictCursor,
        "connect_timeout": 5,
        "read_timeout": 10,
        "write_timeout": 10,
        "autocommit": False,
    }
    if include_database:
        config["database"] = _database_name()
    return config


def _connect(include_database: bool = True):
    try:
        return pymysql.connect(**_connection_kwargs(include_database))
    except AuthError:
        raise
    except Exception as exc:
        raise AuthUnavailable("无法连接 MySQL，请检查数据库服务和连接配置。") from exc


def ensure_auth_schema() -> dict[str, Any]:
    """Create the database and authentication tables when permissions allow it."""
    database = _database_name()
    server_connection = _connect(include_database=False)
    try:
        with server_connection.cursor() as cursor:
            cursor.execute(
                f"CREATE DATABASE IF NOT EXISTS `{database}` "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )
        server_connection.commit()
    finally:
        server_connection.close()

    connection = _connect()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    email VARCHAR(255) NOT NULL,
                    display_name VARCHAR(80) NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    status ENUM('active', 'disabled') NOT NULL DEFAULT 'active',
                    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                        ON UPDATE CURRENT_TIMESTAMP(6),
                    last_login_at DATETIME(6) NULL,
                    PRIMARY KEY (id),
                    UNIQUE KEY users_email_uq (email)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS user_sessions (
                    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
                    user_id BIGINT UNSIGNED NOT NULL,
                    expires_at DATETIME(6) NOT NULL,
                    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                    last_seen_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                    ip_address VARCHAR(45) NULL,
                    user_agent VARCHAR(255) NULL,
                    PRIMARY KEY (token_hash),
                    KEY user_sessions_user_idx (user_id),
                    KEY user_sessions_expires_idx (expires_at),
                    CONSTRAINT user_sessions_user_fk FOREIGN KEY (user_id)
                        REFERENCES users (id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                """
            )
        connection.commit()
    finally:
        connection.close()
    return {"ok": True, "database": database}


def auth_status() -> dict[str, Any]:
    try:
        connection = _connect()
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1 AS ready")
                cursor.fetchone()
        finally:
            connection.close()
        return {"ok": True, "database": _database_name()}
    except AuthError as exc:
        return {"ok": False, "code": exc.code, "error": str(exc)}


def _scrypt(password: str, salt: bytes, n: int, r: int, p: int) -> bytes:
    return hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=n,
        r=r,
        p=p,
        dklen=SCRYPT_LENGTH,
        maxmem=256 * 1024 * 1024,
    )


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = _scrypt(password, salt, SCRYPT_N, SCRYPT_R, SCRYPT_P)
    return f"scrypt${SCRYPT_N}${SCRYPT_R}${SCRYPT_P}${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, n_text, r_text, p_text, salt_hex, digest_hex = stored_hash.split("$", 5)
        if algorithm != "scrypt":
            return False
        n, r, p = int(n_text), int(r_text), int(p_text)
        if n < 2**13 or n > 2**18 or r < 1 or r > 16 or p < 1 or p > 10:
            return False
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(digest_hex)
        actual = _scrypt(password, salt, n, r, p)
        return hmac.compare_digest(actual, expected)
    except (TypeError, ValueError):
        return False


def _dummy_password_check(password: str) -> None:
    _scrypt(password, b"research-platform", SCRYPT_N, SCRYPT_R, SCRYPT_P)


def _normalize_email(value: Any) -> str:
    email = str(value or "").strip().lower()
    if len(email) > 255 or not EMAIL_PATTERN.fullmatch(email):
        raise AuthValidationError("请输入有效的邮箱地址。")
    return email


def _validate_display_name(value: Any) -> str:
    name = re.sub(r"\s+", " ", str(value or "").strip())
    if len(name) < 2 or len(name) > 40:
        raise AuthValidationError("显示名称长度需要为 2–40 个字符。")
    return name


def _validate_password(value: Any) -> str:
    password = str(value or "")
    if len(password) < 8:
        raise AuthValidationError("密码至少需要 8 个字符。")
    if len(password) > 128:
        raise AuthValidationError("密码不能超过 128 个字符。")
    return password


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("ascii", errors="ignore")).hexdigest()


def _public_user(row: dict[str, Any]) -> dict[str, Any]:
    created_at = row.get("created_at")
    return {
        "id": int(row["id"]),
        "email": row["email"],
        "displayName": row["display_name"],
        "createdAt": created_at.isoformat(timespec="seconds") if isinstance(created_at, datetime) else None,
    }


def _create_session(
    connection,
    user_id: int,
    ip_address: str | None,
    user_agent: str | None,
) -> str:
    token = secrets.token_urlsafe(48)
    expires_at = datetime.utcnow() + timedelta(days=SESSION_DAYS)
    with connection.cursor() as cursor:
        cursor.execute("DELETE FROM user_sessions WHERE expires_at <= UTC_TIMESTAMP(6)")
        cursor.execute(
            """
            INSERT INTO user_sessions
                (token_hash, user_id, expires_at, ip_address, user_agent)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                _token_hash(token),
                user_id,
                expires_at,
                (ip_address or "")[:45] or None,
                (user_agent or "")[:255] or None,
            ),
        )
    return token


def _record_attempt(key: str, limit: int = 10, window_seconds: int = 600) -> None:
    now = time.monotonic()
    with _rate_lock:
        recent = [stamp for stamp in _rate_attempts.get(key, []) if now - stamp < window_seconds]
        if len(recent) >= limit:
            _rate_attempts[key] = recent
            raise AuthRateLimited("尝试次数过多，请稍后再试。")
        recent.append(now)
        _rate_attempts[key] = recent


def _clear_attempts(key: str) -> None:
    with _rate_lock:
        _rate_attempts.pop(key, None)


def register_user(payload: dict[str, Any], ip_address: str | None, user_agent: str | None):
    email = _normalize_email(payload.get("email"))
    display_name = _validate_display_name(payload.get("displayName"))
    password = _validate_password(payload.get("password"))
    rate_key = f"register:{ip_address or 'unknown'}"
    _record_attempt(rate_key, limit=6, window_seconds=900)

    connection = _connect()
    try:
        password_hash = hash_password(password)
        with connection.cursor() as cursor:
            try:
                cursor.execute(
                    "INSERT INTO users (email, display_name, password_hash) VALUES (%s, %s, %s)",
                    (email, display_name, password_hash),
                )
            except Exception as exc:
                if getattr(exc, "args", [None])[0] == 1062:
                    raise AuthConflict("该邮箱已经注册。") from exc
                raise
            user_id = int(cursor.lastrowid)
            cursor.execute(
                "SELECT id, email, display_name, created_at FROM users WHERE id = %s",
                (user_id,),
            )
            row = cursor.fetchone()
        token = _create_session(connection, user_id, ip_address, user_agent)
        connection.commit()
        _clear_attempts(rate_key)
        return _public_user(row), token
    except AuthError:
        connection.rollback()
        raise
    except Exception as exc:
        connection.rollback()
        raise AuthUnavailable("注册暂时不可用，请检查数据库服务。") from exc
    finally:
        connection.close()


def authenticate_user(payload: dict[str, Any], ip_address: str | None, user_agent: str | None):
    email = _normalize_email(payload.get("email"))
    password = _validate_password(payload.get("password"))
    rate_key = f"login:{ip_address or 'unknown'}:{email}"
    _record_attempt(rate_key)

    connection = _connect()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, email, display_name, password_hash, status, created_at
                FROM users WHERE email = %s LIMIT 1
                """,
                (email,),
            )
            row = cursor.fetchone()
            if row is None:
                _dummy_password_check(password)
                raise InvalidCredentials("邮箱或密码不正确。")
            if row["status"] != "active" or not verify_password(password, row["password_hash"]):
                raise InvalidCredentials("邮箱或密码不正确。")
            cursor.execute(
                "UPDATE users SET last_login_at = UTC_TIMESTAMP(6) WHERE id = %s",
                (row["id"],),
            )
        token = _create_session(connection, int(row["id"]), ip_address, user_agent)
        connection.commit()
        _clear_attempts(rate_key)
        return _public_user(row), token
    except AuthError:
        connection.rollback()
        raise
    except Exception as exc:
        connection.rollback()
        raise AuthUnavailable("登录暂时不可用，请检查数据库服务。") from exc
    finally:
        connection.close()


def extract_session_token(cookie_header: str | None) -> str | None:
    if not cookie_header:
        return None
    try:
        cookie = SimpleCookie()
        cookie.load(cookie_header)
        morsel = cookie.get(COOKIE_NAME)
        token = morsel.value if morsel else ""
        if len(token) < 32 or len(token) > 256:
            return None
        return token
    except Exception:
        return None


def current_user(cookie_header: str | None) -> dict[str, Any] | None:
    token = extract_session_token(cookie_header)
    if token is None:
        return None
    connection = _connect()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT u.id, u.email, u.display_name, u.created_at
                FROM user_sessions AS s
                INNER JOIN users AS u ON u.id = s.user_id
                WHERE s.token_hash = %s
                  AND s.expires_at > UTC_TIMESTAMP(6)
                  AND u.status = 'active'
                LIMIT 1
                """,
                (_token_hash(token),),
            )
            row = cursor.fetchone()
            if row is not None:
                cursor.execute(
                    "UPDATE user_sessions SET last_seen_at = UTC_TIMESTAMP(6) WHERE token_hash = %s",
                    (_token_hash(token),),
                )
        connection.commit()
        return _public_user(row) if row else None
    except Exception as exc:
        connection.rollback()
        raise AuthUnavailable("无法读取登录状态，请检查数据库服务。") from exc
    finally:
        connection.close()


def logout_user(cookie_header: str | None) -> None:
    token = extract_session_token(cookie_header)
    if token is None:
        return
    connection = _connect()
    try:
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM user_sessions WHERE token_hash = %s", (_token_hash(token),))
        connection.commit()
    except Exception as exc:
        connection.rollback()
        raise AuthUnavailable("退出登录暂时不可用，请检查数据库服务。") from exc
    finally:
        connection.close()


def session_cookie(token: str, secure: bool) -> str:
    parts = [
        f"{COOKIE_NAME}={token}",
        "Path=/",
        f"Max-Age={SESSION_DAYS * 86400}",
        "HttpOnly",
        "SameSite=Lax",
    ]
    if secure:
        parts.append("Secure")
    return "; ".join(parts)


def clear_session_cookie(secure: bool) -> str:
    parts = [
        f"{COOKIE_NAME}=",
        "Path=/",
        "Max-Age=0",
        "Expires=Thu, 01 Jan 1970 00:00:00 GMT",
        "HttpOnly",
        "SameSite=Lax",
    ]
    if secure:
        parts.append("Secure")
    return "; ".join(parts)
