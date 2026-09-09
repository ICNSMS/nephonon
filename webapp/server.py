from __future__ import annotations

import json
import math
import mimetypes
import os
import re
import shutil
import shlex
import subprocess
import sys
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlparse

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize, PowerNorm
import numpy as np

from auth_mysql import (
    MAX_JSON_BYTES,
    AuthError,
    AuthUnavailable,
    auth_status,
    authenticate_user,
    clear_session_cookie,
    current_user,
    ensure_auth_schema,
    logout_user,
    register_user,
    session_cookie,
)

try:
    from scipy.ndimage import gaussian_filter
except Exception:  # pragma: no cover - scipy is optional for the web viewer
    gaussian_filter = None


ROOT = Path(__file__).resolve().parents[1]
WEBAPP_DIR = Path(__file__).resolve().parent
STATIC_DIR = WEBAPP_DIR / "static"
JOBS_DIR = WEBAPP_DIR / "jobs"
PROGRAM_DIR = ROOT / "Program" if (ROOT / "Program" / "src" / "nephonon.f90").is_file() else ROOT
DEFAULT_EXE_CANDIDATES = [
    PROGRAM_DIR / "src" / ("nephonon.exe" if os.name == "nt" else "nephonon"),
    PROGRAM_DIR / "src" / "nephonon.exe",
    PROGRAM_DIR / "windowsexe" / "nephonon.exe",
]
DEFAULT_EXE_PATH = next((path for path in DEFAULT_EXE_CANDIDATES if path.exists()), DEFAULT_EXE_CANDIDATES[-1])

WORKFLOW_PLOTS = "plots"
WORKFLOW_FORCE_CONSTANTS = "force_constants"

PLOT_UPLOAD_FIELDS = {
    "control": "inp.control",
    "cif": "structure.cif",
    "force_constants": "FORCE_CONSTANTS",
    "loto": "inp.lotosplitting",
}

FORCE_CONSTANT_UPLOAD_FIELDS = {
    "control": "inp.control",
    "cif": "structure.cif",
    "nep": "nep.txt",
}

FORCE_CONSTANT_PATCH = {
    "gen2ndfc": True,
    "dos": False,
    "band": False,
    "velocity": False,
    "eigenvector": False,
    "nonanalytic": False,
    "isosurface": False,
    "sqw_crystal": False,
    "sqw_powder": False,
}

PLOT_PATCH = {
    "gen2ndfc": False,
}

EXAMPLES = {
    "pbte_band_dos": {
        "name": "PbTe band + DOS",
        "description": "Combined phonon band and density-of-states plot.",
        "files": [
            ("webapp/examples/pbte_band_dos.inp.control", "inp.control"),
            (PROGRAM_DIR / "example" / "PbTe" / "FORCE_CONSTANTS", "FORCE_CONSTANTS"),
        ],
    },
    "zno_band": {
        "name": "ZnO phonon band",
        "description": "Band structure with non-analytic LO-TO correction.",
        "files": [
            (PROGRAM_DIR / "example" / "ZnO" / "inp.control", "inp.control"),
            (PROGRAM_DIR / "example" / "ZnO" / "FORCE_CONSTANTS", "FORCE_CONSTANTS"),
            (PROGRAM_DIR / "example" / "ZnO" / "inp.lotosplitting", "inp.lotosplitting"),
        ],
    },
    "csi_sqw": {
        "name": "CsI single-crystal S(Q,E)",
        "description": "Single-crystal neutron scattering map.",
        "files": [
            (PROGRAM_DIR / "example" / "CsI" / "inp.control", "inp.control"),
            (PROGRAM_DIR / "example" / "CsI" / "FORCE_CONSTANTS", "FORCE_CONSTANTS"),
        ],
    },
    "graphene_surface": {
        "name": "Graphene band + isosurface",
        "description": "Band structure and FermiSurfer isosurface data.",
        "files": [
            (PROGRAM_DIR / "example" / "graphene" / "inp.control", "inp.control"),
            (PROGRAM_DIR / "example" / "graphene" / "FORCE_CONSTANTS", "FORCE_CONSTANTS"),
        ],
    },
    "nacl_sqw": {
        "name": "NaCl single-crystal S(Q,E)",
        "description": "Single-crystal scattering along a Q path.",
        "files": [
            (PROGRAM_DIR / "example" / "NaCl" / "inp.control", "inp.control"),
            (PROGRAM_DIR / "example" / "NaCl" / "FORCE_CONSTANTS", "FORCE_CONSTANTS"),
        ],
    },
}

PLOT_CMAPS = {"Blues", "jet", "viridis", "magma", "plasma", "cividis", "turbo"}


class FormField:
    def __init__(self, name: str, data: bytes, filename: str | None = None) -> None:
        self.name = name
        self.data = data
        self.filename = filename

    @property
    def value(self) -> str:
        return self.data.decode("utf-8", errors="replace")


class MultipartForm(dict):
    def add(self, field: FormField) -> None:
        current = self.get(field.name)
        if current is None:
            self[field.name] = field
        elif isinstance(current, list):
            current.append(field)
        else:
            self[field.name] = [current, field]


def json_response(
    handler: BaseHTTPRequestHandler,
    payload: dict,
    status: int = 200,
    extra_headers: dict[str, str] | None = None,
) -> None:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    for key, value in (extra_headers or {}).items():
        handler.send_header(key, value)
    handler.end_headers()
    handler.wfile.write(body)


def text_response(handler: BaseHTTPRequestHandler, text: str, status: int = 404) -> None:
    body = text.encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "text/plain; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def redirect_response(handler: BaseHTTPRequestHandler, location: str, status: int = 302) -> None:
    handler.send_response(status)
    handler.send_header("Location", location)
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", "0")
    handler.end_headers()


def request_uses_https(handler: BaseHTTPRequestHandler) -> bool:
    configured = os.environ.get("AUTH_COOKIE_SECURE", "").strip().lower()
    if configured in {"1", "true", "yes", "on"}:
        return True
    if configured in {"0", "false", "no", "off"}:
        return False
    return handler.headers.get("X-Forwarded-Proto", "").split(",", 1)[0].strip().lower() == "https"


def request_has_valid_origin(handler: BaseHTTPRequestHandler) -> bool:
    origin = handler.headers.get("Origin", "").strip()
    if not origin:
        return True
    parsed = urlparse(origin)
    return parsed.scheme in {"http", "https"} and parsed.netloc == handler.headers.get("Host", "")


def safe_output_path(job_id: str, rel_path: str) -> Path | None:
    if not re.fullmatch(r"[0-9A-Za-z_.-]+", job_id):
        return None
    job_dir = (JOBS_DIR / job_id).resolve()
    target = (job_dir / rel_path).resolve()
    try:
        target.relative_to(job_dir)
    except ValueError:
        return None
    return target


def new_job_dir() -> tuple[str, Path]:
    JOBS_DIR.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    job_id = f"{stamp}-{uuid.uuid4().hex[:8]}"
    job_dir = JOBS_DIR / job_id
    job_dir.mkdir(parents=True)
    return job_id, job_dir


def field_value(form: MultipartForm, name: str, default: str = "") -> str:
    item = form[name] if name in form else None
    if item is None or isinstance(item, list):
        return default
    if item.filename:
        return default
    return item.value


def field_bool(form: MultipartForm, name: str, default: bool = False) -> bool:
    value = field_value(form, name, "true" if default else "false").strip().lower()
    return value in {"1", "true", ".true.", "yes", "on"}


def file_field(form: MultipartForm, field_name: str) -> FormField | None:
    if field_name not in form:
        return None
    item = form[field_name]
    if isinstance(item, list):
        item = item[0] if item else None
    if item is None or not getattr(item, "filename", None):
        return None
    return item


def save_file_field(form: MultipartForm, field_name: str, dest: Path) -> bool:
    item = file_field(form, field_name)
    if item is None:
        return False
    with dest.open("wb") as fh:
        fh.write(item.data)
    return True


def normalize_workflow(value: str) -> str:
    if value in {WORKFLOW_FORCE_CONSTANTS, "fc", "force"}:
        return WORKFLOW_FORCE_CONSTANTS
    return WORKFLOW_PLOTS


def tokenize_cif_line(line: str) -> list[str]:
    lexer = shlex.shlex(line, posix=True)
    lexer.whitespace_split = True
    lexer.commenters = "#"
    try:
        return list(lexer)
    except ValueError:
        return line.split()


def cif_number(raw: str) -> float | None:
    value = raw.strip().strip("'\"")
    if value in {"", ".", "?"}:
        return None
    value = value.replace("D", "E").replace("d", "e")
    match = re.match(
        r"^([+-]?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+))(?:[Ee][+-]?\d+)?)(?:\(\d+\))?$",
        value,
    )
    if not match:
        return None
    try:
        return float(match.group(1))
    except ValueError:
        return None


def format_cif_float(value: float) -> str:
    if abs(value) < 5e-12:
        value = 0.0
    return f"{value:.10f}"


def normalize_element(raw: str) -> str:
    value = raw.strip().strip("'\"")
    match = re.match(r"([A-Za-z]{1,2})", value)
    if not match:
        return value or "X"
    letters = match.group(1)
    if len(letters) == 1:
        return letters.upper()
    return letters[0].upper() + letters[1].lower()


def lattice_from_cell(a: float, b: float, c: float, alpha: float, beta: float, gamma: float) -> list[list[float]]:
    ar = math.radians(alpha)
    br = math.radians(beta)
    gr = math.radians(gamma)
    sin_gamma = math.sin(gr)
    if abs(sin_gamma) < 1e-10:
        raise ValueError("CIF cell angle gamma is invalid")
    ax, ay, az = a, 0.0, 0.0
    bx, by, bz = b * math.cos(gr), b * sin_gamma, 0.0
    cx = c * math.cos(br)
    cy = c * (math.cos(ar) - math.cos(br) * math.cos(gr)) / sin_gamma
    cz2 = c * c - cx * cx - cy * cy
    cz = math.sqrt(max(cz2, 0.0))
    return [[ax, ay, az], [bx, by, bz], [cx, cy, cz]]


def cif_scalar_values(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        tokens = tokenize_cif_line(line.strip())
        if len(tokens) >= 2 and tokens[0].startswith("_"):
            values[tokens[0].lower()] = tokens[1]
    return values


def cif_loop_rows(text: str) -> list[tuple[list[str], list[list[str]]]]:
    lines = text.splitlines()
    blocks: list[tuple[list[str], list[list[str]]]] = []
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped.lower() != "loop_":
            i += 1
            continue
        i += 1
        headers: list[str] = []
        while i < len(lines):
            tokens = tokenize_cif_line(lines[i].strip())
            if not tokens or not tokens[0].startswith("_"):
                break
            headers.append(tokens[0].lower())
            i += 1
        data_tokens: list[str] = []
        while i < len(lines):
            stripped = lines[i].strip()
            lower = stripped.lower()
            if lower == "loop_" or lower.startswith("data_") or stripped.startswith("_"):
                break
            data_tokens.extend(tokenize_cif_line(stripped))
            i += 1
        if headers:
            width = len(headers)
            rows = [
                data_tokens[start : start + width]
                for start in range(0, len(data_tokens), width)
                if len(data_tokens[start : start + width]) == width
            ]
            blocks.append((headers, rows))
    return blocks


def parse_cif_text(text: str) -> dict:
    scalars = cif_scalar_values(text)
    required_cell = [
        "_cell_length_a",
        "_cell_length_b",
        "_cell_length_c",
        "_cell_angle_alpha",
        "_cell_angle_beta",
        "_cell_angle_gamma",
    ]
    cell_values = {key: cif_number(scalars.get(key, "")) for key in required_cell}
    if any(value is None for value in cell_values.values()):
        raise ValueError("CIF is missing cell lengths or angles")

    lattice = lattice_from_cell(
        cell_values["_cell_length_a"],
        cell_values["_cell_length_b"],
        cell_values["_cell_length_c"],
        cell_values["_cell_angle_alpha"],
        cell_values["_cell_angle_beta"],
        cell_values["_cell_angle_gamma"],
    )

    atoms: list[dict] = []
    coordinate_mode = "Direct"
    for headers, rows in cif_loop_rows(text):
        lower_headers = [header.lower() for header in headers]
        if not any(header.startswith("_atom_site_") for header in lower_headers):
            continue

        def index_of(*names: str) -> int | None:
            for name in names:
                if name in lower_headers:
                    return lower_headers.index(name)
            return None

        element_idx = index_of("_atom_site_type_symbol", "_atom_site_label")
        label_idx = index_of("_atom_site_label")
        fx_idx = index_of("_atom_site_fract_x")
        fy_idx = index_of("_atom_site_fract_y")
        fz_idx = index_of("_atom_site_fract_z")
        cx_idx = index_of("_atom_site_cartn_x")
        cy_idx = index_of("_atom_site_cartn_y")
        cz_idx = index_of("_atom_site_cartn_z")
        occupancy_idx = index_of("_atom_site_occupancy")

        has_fractional = fx_idx is not None and fy_idx is not None and fz_idx is not None
        has_cartesian = cx_idx is not None and cy_idx is not None and cz_idx is not None
        if not has_fractional and not has_cartesian:
            continue

        coordinate_mode = "Direct" if has_fractional else "Cartesian"
        for row in rows:
            if occupancy_idx is not None:
                occupancy = cif_number(row[occupancy_idx])
                if occupancy is not None and occupancy <= 0:
                    continue
            raw_element = row[element_idx] if element_idx is not None else row[label_idx] if label_idx is not None else "X"
            element = normalize_element(raw_element)
            indices = (fx_idx, fy_idx, fz_idx) if has_fractional else (cx_idx, cy_idx, cz_idx)
            coords = [cif_number(row[index]) for index in indices if index is not None]
            if len(coords) != 3 or any(value is None for value in coords):
                continue
            atoms.append(
                {
                    "element": element,
                    "label": row[label_idx] if label_idx is not None else element,
                    "coords": [float(value) for value in coords],
                    "coordinateMode": coordinate_mode,
                }
            )
        if atoms:
            break

    if not atoms:
        raise ValueError("CIF atom positions were not found")

    elements: list[str] = []
    for atom in atoms:
        if atom["element"] not in elements:
            elements.append(atom["element"])
    grouped_atoms = [atom for element in elements for atom in atoms if atom["element"] == element]
    counts = [sum(1 for atom in grouped_atoms if atom["element"] == element) for element in elements]

    lattice_text = "\n".join(" ".join(format_cif_float(value) for value in vector) for vector in lattice)
    positions_text = "\n".join(" ".join(format_cif_float(value) for value in atom["coords"]) for atom in grouped_atoms)
    return {
        "ntypes": str(len(elements)),
        "natoms": str(len(grouped_atoms)),
        "natomCount": len(grouped_atoms),
        "elements": " ".join(elements),
        "nat": " ".join(str(count) for count in counts),
        "coordinate_mode": coordinate_mode,
        "lattice": lattice_text,
        "positions": positions_text,
        "atoms": grouped_atoms,
        "cell": {
            "a": cell_values["_cell_length_a"],
            "b": cell_values["_cell_length_b"],
            "c": cell_values["_cell_length_c"],
            "alpha": cell_values["_cell_angle_alpha"],
            "beta": cell_values["_cell_angle_beta"],
            "gamma": cell_values["_cell_angle_gamma"],
        },
        "summary": f"{len(grouped_atoms)} atoms, {len(elements)} species: {' '.join(elements)}",
    }


def parse_cif_from_form(form: MultipartForm) -> dict | None:
    item = file_field(form, "cif")
    if item is None:
        return None
    return parse_cif_text(item.value)


def quoted_elements(raw: str) -> str:
    values = [value.strip().strip("'\"") for value in re.split(r"[\s,]+", raw) if value.strip()]
    return " ".join(f'"{value}"' for value in values) or '"Cu"'


def count_nonempty_lines(raw: str) -> int:
    return sum(1 for line in raw.splitlines() if line.strip())


def builder_value(form: MultipartForm, name: str, default: str) -> str:
    return field_value(form, f"builder_{name}", default).strip() or default


def build_control_from_form(form: MultipartForm, workflow: str) -> str:
    force_mode = workflow == WORKFLOW_FORCE_CONSTANTS
    try:
        cif_defaults = parse_cif_from_form(form) or {}
    except ValueError:
        cif_defaults = {}
    default_lattice = (
        "0.0000000000000000 2.0285682794499998 2.0285682794499998\n"
        "2.0285682794499998 0.0000000000000000 2.0285682794499998\n"
        "2.0285682794499998 2.0285682794499998 0.0000000000000000"
        if force_mode
        else
        "0.0000000000 3.2708968787 3.2708968787\n"
        "3.2708968787 0.0000000000 3.2708968787\n"
        "3.2708968787 3.2708968787 0.0000000000"
    )
    default_positions = (
        "0.00 0.00 0.00"
        if force_mode
        else "0.500000000 0.500000000 0.500000000\n0.000000000 0.000000000 0.000000000"
    )
    ntypes = builder_value(form, "ntypes", cif_defaults.get("ntypes", "1" if force_mode else "2"))
    natoms = builder_value(form, "natoms", cif_defaults.get("natoms", "1" if force_mode else "2"))
    nsize = builder_value(form, "nsize", "4 4 4" if force_mode else "5 5 5")
    elements = quoted_elements(builder_value(form, "elements", cif_defaults.get("elements", "Cu" if force_mode else "Pb Te")))
    nat = builder_value(form, "nat", cif_defaults.get("nat", "1" if force_mode else "1 1"))
    displace_delta = builder_value(form, "displace_delta", "0.01")
    lattice = builder_value(form, "lattice", cif_defaults.get("lattice", default_lattice))
    coordinate_mode = builder_value(form, "coordinate_mode", cif_defaults.get("coordinate_mode", "Direct"))
    positions = builder_value(form, "positions", cif_defaults.get("positions", default_positions))

    dos = False if force_mode else field_bool(form, "builder_dos", True)
    band = False if force_mode else field_bool(form, "builder_band", True)
    isosurface = False if force_mode else field_bool(form, "builder_isosurface", False)
    sqw_crystal = False if force_mode else field_bool(form, "builder_sqw_crystal", False)
    sqw_powder = False if force_mode else field_bool(form, "builder_sqw_powder", False)
    velocity = False if force_mode else field_bool(form, "builder_velocity", False)
    eigenvector = False if force_mode else field_bool(form, "builder_eigenvector", False)
    fc_symmetry = field_bool(form, "builder_fc_symmetry", True if force_mode else False)
    nonanalytic = False if force_mode else field_bool(form, "builder_nonanalytic", False)

    def tf(value: bool) -> str:
        return ".true." if value else ".false."

    text = f"""&basic
     ntypes = {ntypes}
     natoms = {natoms}
      nsize = {nsize}
/

&inputph
   elements = {elements}
        nat = {nat}
   gen2ndfc = {tf(force_mode)}
        dos = {tf(dos)}
       band = {tf(band)}
   velocity = {tf(velocity)}
eigenvector = {tf(eigenvector)}
fc_symmetry = {tf(fc_symmetry)}
nonanalytic = {tf(nonanalytic)}
 isosurface = {tf(isosurface)}
sqw_crystal = {tf(sqw_crystal)}
 sqw_powder = {tf(sqw_powder)}
/
"""

    if sqw_crystal or sqw_powder:
        text += f"""
&inputsqw
     lphase = {tf(field_bool(form, "builder_lphase", True))}
   dw_qmesh = {builder_value(form, "dw_qmesh", "10 10 10")}
temperature = {builder_value(form, "temperature", "30")}
      e_min = {builder_value(form, "e_min", "0.0")}
      e_max = {builder_value(form, "e_max", "40.0")}
    ne_bins = {builder_value(form, "ne_bins", "501")}
 e_smearing = {builder_value(form, "e_smearing", "0.6 0.0 0.001 0.0 0.0")}
/
"""

    text += f"""
Displace_DELTA
{displace_delta}
"""

    if dos:
        text += f"""
DOS_SIGMA
{builder_value(form, "dos_sigma", "0.02")}

DENSITY_OF_STATES
{builder_value(form, "dos_qmesh", "40 40 40")}
"""

    bands_structure = builder_value(
        form,
        "bands_structure",
        (
            "0.000 0.000 0.000  0.500 0.000 0.500 100 ! G-X\n"
            "0.500 0.000 0.500  0.625 0.250 0.625 100 ! X-U\n"
            "0.375 0.375 0.750  0.000 0.000 0.000 100 ! K-G\n"
            "0.000 0.000 0.000  0.500 0.500 0.500 100 ! G-L\n"
            "0.500 0.500 0.500  0.500 0.250 0.750 100 ! L-W\n"
            "0.500 0.250 0.750  0.500 0.000 0.500 100 ! W-X"
        ),
    )
    if band or sqw_crystal:
        text += f"""
BANDS_STRUCTURE
{max(count_nonempty_lines(bands_structure), 1)}
{bands_structure}
"""

    if isosurface:
        text += f"""
ISOSURFACE
{builder_value(form, "isosurface_qmesh", "80 80 1")}
"""

    text += f"""
LATTICE_PARAMETERS
{lattice}

ATOMIC_POSITIONS
{coordinate_mode}
{positions}
"""
    return text.strip() + "\n"


def save_control_from_builder(form: MultipartForm, job_dir: Path, workflow: str) -> bool:
    if not field_bool(form, "control_builder", False):
        return False
    (job_dir / "inp.control").write_text(build_control_from_form(form, workflow), encoding="utf-8")
    return True


def prepare_inputs(form: MultipartForm, job_dir: Path, workflow: str) -> tuple[list[str], list[str], str]:
    warnings: list[str] = []
    saved: list[str] = []
    source = field_value(form, "source", "example")
    example_id = field_value(form, "example", "zno_band")

    if workflow == WORKFLOW_FORCE_CONSTANTS:
        for field, filename in FORCE_CONSTANT_UPLOAD_FIELDS.items():
            if save_file_field(form, field, job_dir / filename):
                saved.append(filename)
        if "inp.control" not in saved:
            if save_control_from_builder(form, job_dir, workflow):
                saved.append("inp.control")
            elif save_control_text(form, job_dir):
                saved.append("inp.control")
        patch_control_file(job_dir / "inp.control", FORCE_CONSTANT_PATCH)
        return saved, warnings, WORKFLOW_FORCE_CONSTANTS

    if source == "builder":
        for field, filename in PLOT_UPLOAD_FIELDS.items():
            if field == "control":
                continue
            if save_file_field(form, field, job_dir / filename):
                saved.append(filename)
        if save_control_from_builder(form, job_dir, workflow) and "inp.control" not in saved:
            saved.append("inp.control")
        patch_control_file(job_dir / "inp.control", PLOT_PATCH)
        return saved, warnings, "builder"

    if source == "example":
        example = EXAMPLES.get(example_id, EXAMPLES["zno_band"])
        for src, name in example["files"]:
            src_path = src if isinstance(src, Path) else ROOT / src
            if src_path.exists():
                shutil.copy2(src_path, job_dir / name)
                saved.append(name)
            else:
                warnings.append(f"Example file missing: {src}")
        patch = example.get("patch_control")
        if patch:
            patch_control_file(job_dir / "inp.control", patch)
        if save_control_text(form, job_dir) and "inp.control" not in saved:
            saved.append("inp.control")
        patch_control_file(job_dir / "inp.control", PLOT_PATCH)
        return saved, warnings, example_id

    for field, filename in PLOT_UPLOAD_FIELDS.items():
        if save_file_field(form, field, job_dir / filename):
            saved.append(filename)
    if save_control_text(form, job_dir) and "inp.control" not in saved:
        saved.append("inp.control")
    patch_control_file(job_dir / "inp.control", PLOT_PATCH)

    return saved, warnings, "upload"


def save_control_text(form: MultipartForm, job_dir: Path) -> bool:
    text = field_value(form, "control_text", "")
    if not text.strip():
        return False
    (job_dir / "inp.control").write_text(text, encoding="utf-8")
    return True


def patch_control_text(text: str, patch: dict[str, bool]) -> str:
    missing: list[str] = []
    for key, value in patch.items():
        replacement = f"{key} = {'.true.' if value else '.false.'}"
        if re.search(rf"\b{re.escape(key)}\s*=\s*\.?\s*(true|false)\s*\.?", text, re.I):
            text = re.sub(
                rf"\b{re.escape(key)}\s*=\s*\.?\s*(true|false)\s*\.?",
                replacement,
                text,
                count=1,
                flags=re.I,
            )
        else:
            missing.append(f"   {replacement}")
    if missing:
        insert = "\n".join(missing) + "\n"

        def add_missing(match: re.Match) -> str:
            return f"{match.group(1)}{insert}{match.group(2)}"

        text = re.sub(r"(?is)(&inputph\b.*?)(\n\s*/)", add_missing, text, count=1)
    return text


def patch_control_file(path: Path, patch: dict[str, bool]) -> None:
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8", errors="ignore")
    text = patch_control_text(text, patch)
    path.write_text(text, encoding="utf-8")


def example_control_text(example_id: str, workflow: str) -> tuple[str, str] | None:
    example = EXAMPLES.get(example_id, EXAMPLES["zno_band"])
    for src, name in example["files"]:
        if name != "inp.control":
            continue
        path = src if isinstance(src, Path) else ROOT / src
        if not path.exists():
            return None
        text = path.read_text(encoding="utf-8", errors="ignore")
        if workflow == WORKFLOW_FORCE_CONSTANTS:
            text = patch_control_text(text, FORCE_CONSTANT_PATCH)
        else:
            text = patch_control_text(text, PLOT_PATCH)
        return text, example["name"]
    return None


def read_control_flags(job_dir: Path) -> dict[str, bool]:
    control = job_dir / "inp.control"
    if not control.exists():
        return {}
    raw = control.read_text(encoding="utf-8", errors="ignore")
    lines = [line.split("!", 1)[0] for line in raw.splitlines()]
    text = "\n".join(lines)
    flags = {}
    for key in [
        "gen2ndfc",
        "dos",
        "band",
        "velocity",
        "eigenvector",
        "fc_symmetry",
        "nonanalytic",
        "isosurface",
        "sqw_crystal",
        "sqw_powder",
    ]:
        match = re.search(rf"\b{key}\s*=\s*\.?\s*(true|false)\s*\.?", text, re.I)
        flags[key] = bool(match and match.group(1).lower() == "true")
    return flags


def validate_plot_inputs(job_dir: Path, flags: dict[str, bool]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    if not (job_dir / "inp.control").exists():
        errors.append("Missing required file: inp.control")
        return errors, warnings

    if flags.get("gen2ndfc", False):
        errors.append(
            "Plot Images module does not generate FORCE_CONSTANTS. Use Generate FORCE_CONSTANTS first, "
            "then upload the generated FORCE_CONSTANTS here with gen2ndfc = .false."
        )

    needs_fc = any(flags.get(k, False) for k in ["dos", "band", "isosurface", "sqw_crystal", "sqw_powder"])
    if needs_fc and not (job_dir / "FORCE_CONSTANTS").exists():
        errors.append("Missing required file: FORCE_CONSTANTS")

    if flags.get("nonanalytic", False) and not (job_dir / "inp.lotosplitting").exists():
        errors.append("Missing required file: inp.lotosplitting because nonanalytic = .true.")

    if flags.get("sqw_crystal", False) and "BANDS_STRUCTURE" not in (job_dir / "inp.control").read_text(errors="ignore"):
        errors.append("BANDS_STRUCTURE block is required for sqw_crystal.")

    return errors, warnings


def validate_force_constant_inputs(job_dir: Path, flags: dict[str, bool]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    control = job_dir / "inp.control"
    if not control.exists():
        errors.append("Missing required file: inp.control")
        return errors, warnings
    if not (job_dir / "nep.txt").exists():
        errors.append("Missing required file: nep.txt")
    if not flags.get("gen2ndfc", False):
        errors.append("Could not enable gen2ndfc in inp.control; check the &inputph block.")
    control_text = control.read_text(encoding="utf-8", errors="ignore")
    if "Displace_DELTA" not in control_text:
        warnings.append("Displace_DELTA block was not found; NEPHONON may use its internal default or stop.")
    return errors, warnings


def validate_inputs(job_dir: Path, flags: dict[str, bool], workflow: str) -> tuple[list[str], list[str]]:
    if workflow == WORKFLOW_FORCE_CONSTANTS:
        return validate_force_constant_inputs(job_dir, flags)
    return validate_plot_inputs(job_dir, flags)


def nephonon_command() -> list[str]:
    raw_command = os.environ.get("NEPHONON_CMD", "").strip()
    if raw_command:
        return shlex.split(raw_command, posix=os.name != "nt")
    raw_exe = os.environ.get("NEPHONON_EXE", "").strip()
    exe_path = Path(raw_exe) if raw_exe else DEFAULT_EXE_PATH
    return [str(exe_path)]


def command_is_available(command: list[str]) -> bool:
    if not command:
        return False
    executable = command[0]
    if any(separator in executable for separator in ("/", "\\")) or executable.endswith(".exe"):
        return Path(executable).exists()
    return shutil.which(executable) is not None


def run_nephonon(job_dir: Path) -> dict:
    started = time.time()
    timeout = int(os.environ.get("NEPHONON_TIMEOUT", "900"))
    env = os.environ.copy()
    if os.name == "nt":
        dll_dirs = [PROGRAM_DIR / "src", PROGRAM_DIR / "windowsexe"]
        env["PATH"] = os.pathsep.join(str(path) for path in dll_dirs if path.exists()) + os.pathsep + env.get("PATH", "")
    completed = subprocess.run(
        nephonon_command(),
        cwd=job_dir,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )
    return {
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "duration": round(time.time() - started, 2),
    }


def load_numeric(path: Path) -> np.ndarray | None:
    try:
        data = np.loadtxt(path, comments="#")
    except Exception:
        return None
    if data.size == 0:
        return None
    if data.ndim == 1:
        data = data.reshape(1, -1)
    return data


def plot_band(path: Path, plots_dir: Path) -> dict | None:
    data = load_numeric(path)
    if data is None or data.shape[1] < 2:
        return None
    x = data[:, 0]
    y = data[:, 1]
    out = plots_dir / "phononband.png"
    fig, ax = plt.subplots(figsize=(8, 4.8), dpi=170)
    ax.plot(x, y, ".", markersize=1.8, color="#1f5aa6")
    ax.set_xlim(float(np.nanmin(x)), float(np.nanmax(x)))
    ymin, ymax = float(np.nanmin(y)), float(np.nanmax(y))
    margin = max((ymax - ymin) * 0.06, 1.0)
    ax.set_ylim(ymin - margin, ymax + margin)
    ax.set_xlabel("Q path")
    ax.set_ylabel("Energy (meV)")
    ax.set_title("Phonon band structure")
    ax.grid(True, which="major", color="#d8dee9", linewidth=0.7)
    ax.grid(True, which="minor", color="#edf1f5", linewidth=0.4)
    ax.minorticks_on()
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)
    return {"kind": "band", "name": out.name, "path": f"plots/{out.name}"}


def plot_dos(path: Path, plots_dir: Path) -> dict | None:
    data = load_numeric(path)
    if data is None or data.shape[1] < 2:
        return None
    out = plots_dir / "phonondos.png"
    fig, ax = plt.subplots(figsize=(7.4, 4.8), dpi=170)
    x = data[:, 0]
    for idx in range(1, data.shape[1]):
        ax.plot(x, data[:, idx], linewidth=1.0, label=f"width {idx}")
    ax.set_xlim(float(np.nanmin(x)), float(np.nanmax(x)))
    ax.set_xlabel("Energy (meV)")
    ax.set_ylabel("DOS")
    ax.set_title("Phonon density of states")
    if data.shape[1] <= 7:
        ax.legend(fontsize=7, frameon=False)
    ax.grid(True, color="#e4e9f2", linewidth=0.6)
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)
    return {"kind": "dos", "name": out.name, "path": f"plots/{out.name}"}


def draw_band_axis(ax, band_data: np.ndarray, title: str = "Phonon band structure") -> tuple[float, float]:
    x = band_data[:, 0]
    y = band_data[:, 1]
    marker_size = 1.6 if len(y) < 10000 else 0.45
    ax.plot(x, y, ".", markersize=marker_size, color="#111111")
    ax.set_xlim(float(np.nanmin(x)), float(np.nanmax(x)))
    ymin, ymax = float(np.nanmin(y)), float(np.nanmax(y))
    margin = max((ymax - ymin) * 0.04, 1.0)
    ax.set_ylim(ymin - margin, ymax + margin)
    ax.set_xlabel("Q path")
    ax.set_ylabel("Energy (meV)")
    ax.set_title(title)
    ax.grid(True, axis="x", color="#d2d7df", linestyle=":", linewidth=0.8)
    return ymin - margin, ymax + margin


def plot_band_dos(band_path: Path, dos_path: Path, plots_dir: Path) -> dict | None:
    band = load_numeric(band_path)
    if band is None or band.shape[1] < 2:
        return None

    out = plots_dir / "band_dos.png"
    fig, ax_band = plt.subplots(figsize=(7.2, 5.2), dpi=170)
    draw_band_axis(ax_band, band, "Band structure")
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)
    return {"kind": "band", "name": out.name, "path": f"plots/{out.name}"}


def parse_phononsurface(path: Path) -> dict | None:
    try:
        lines = [line.strip() for line in path.read_text(errors="ignore").splitlines() if line.strip()]
        dims = [int(value) for value in lines[0].split()[:3]]
        nbands = int(lines[2].split()[0])
        rlat = np.array([[float(v) for v in lines[3 + i].split()[:3]] for i in range(3)])
        values = np.array([float(line.split()[0]) for line in lines[6:]], dtype=float)
    except Exception:
        return None
    nx, ny, nz = dims
    expected = nx * ny * nz * nbands
    if values.size < expected:
        return None
    values = values[:expected].reshape(nbands, nz, ny, nx)
    return {"dims": dims, "nbands": nbands, "rlat": rlat, "values": values}


def isosurface_levels(surface: dict) -> list[float]:
    values = surface["values"]
    vmin = float(np.nanmin(values))
    vmax = float(np.nanmax(values))
    preferred = [110.0, 50.0]
    levels = [level for level in preferred if vmin <= level <= vmax]
    if len(levels) >= 2:
        return levels[:2]
    fallback = [float(np.nanpercentile(values, 65)), float(np.nanpercentile(values, 35))]
    for level in fallback:
        if vmin <= level <= vmax and all(abs(level - existing) > 1e-6 for existing in levels):
            levels.append(level)
        if len(levels) >= 2:
            break
    return levels or [(vmin + vmax) / 2.0]


def draw_iso_axis(ax, surface: dict, level: float) -> None:
    nx, ny, nz = surface["dims"]
    values = surface["values"]
    if nz != 1:
        ax.text(0.5, 0.5, "3D surface data\nDownload .fs file", ha="center", va="center", transform=ax.transAxes)
        ax.set_axis_off()
        return

    xs = np.linspace(-0.5, 0.5, nx)
    ys = np.linspace(-0.5, 0.5, ny)
    x_grid, y_grid = np.meshgrid(xs, ys)
    colors = plt.cm.turbo(np.linspace(0.05, 0.92, surface["nbands"]))
    radius = 0.53
    angles = np.linspace(np.pi / 6.0, 2.0 * np.pi + np.pi / 6.0, 7)
    hex_xy = np.column_stack([radius * np.cos(angles), radius * np.sin(angles)])
    from matplotlib.patches import Polygon

    hex_patch = Polygon(hex_xy[:-1], closed=True, fill=False, edgecolor="none", transform=ax.transData)
    ax.add_patch(hex_patch)
    drew = False
    for band_idx in range(surface["nbands"]):
        z = np.fft.fftshift(values[band_idx, 0, :, :])
        if float(np.nanmin(z)) <= level <= float(np.nanmax(z)):
            contour = ax.contour(x_grid, y_grid, z, levels=[level], colors=[colors[band_idx]], linewidths=1.25)
            if hasattr(contour, "collections"):
                for collection in contour.collections:
                    collection.set_clip_path(hex_patch)
            elif hasattr(contour, "set_clip_path"):
                contour.set_clip_path(hex_patch)
            drew = True

    ax.plot(radius * np.cos(angles), radius * np.sin(angles), color="#111111", linewidth=1.6)
    ax.set_aspect("equal", adjustable="box")
    ax.set_xlim(-0.62, 0.62)
    ax.set_ylim(-0.62, 0.62)
    ax.set_xticks([])
    ax.set_yticks([])
    ax.set_title(f"{level:g} meV", fontsize=10, fontweight="bold")
    if not drew:
        ax.text(0.5, 0.5, "No contour at this level", ha="center", va="center", transform=ax.transAxes, fontsize=8)


def plot_band_isosurface(band_path: Path, surface_path: Path, plots_dir: Path) -> dict | None:
    band = load_numeric(band_path)
    surface = parse_phononsurface(surface_path)
    if band is None or surface is None or band.shape[1] < 2:
        return None

    levels = isosurface_levels(surface)
    out = plots_dir / "band_isosurface.png"
    fig = plt.figure(figsize=(8.6, 5.7), dpi=170)
    grid = fig.add_gridspec(2, 2, width_ratios=[1.35, 1.0], hspace=0.22, wspace=0.18)
    ax_band = fig.add_subplot(grid[:, 0])
    draw_band_axis(ax_band, band, "Band structure")
    ax_band.lines[-1].set_color("#b91c1c")
    ax_band.lines[-1].set_markersize(1.6 if len(band) < 10000 else 0.55)

    ax_iso_1 = fig.add_subplot(grid[0, 1])
    draw_iso_axis(ax_iso_1, surface, levels[0])
    ax_iso_2 = fig.add_subplot(grid[1, 1])
    draw_iso_axis(ax_iso_2, surface, levels[min(1, len(levels) - 1)])
    fig.suptitle("Band structure + iso-frequency contours", y=0.98, fontsize=12, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(out)
    plt.close(fig)
    return {"kind": "band_isosurface", "name": out.name, "path": f"plots/{out.name}"}


def plot_isosurface(surface_path: Path, plots_dir: Path) -> dict | None:
    surface = parse_phononsurface(surface_path)
    if surface is None:
        return None
    levels = isosurface_levels(surface)
    out = plots_dir / "isosurface.png"
    fig, axes = plt.subplots(1, len(levels), figsize=(4.2 * len(levels), 4.0), dpi=170)
    if len(levels) == 1:
        axes = [axes]
    for ax, level in zip(axes, levels):
        draw_iso_axis(ax, surface, level)
    fig.suptitle("Iso-frequency contours", y=0.96, fontsize=12, fontweight="bold")
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)
    return {"kind": "isosurface", "name": out.name, "path": f"plots/{out.name}"}


def normalize_q_label(label: str) -> str:
    label = label.strip().strip("()[]{}")
    aliases = {
        "G": r"$\Gamma$",
        "GAMMA": r"$\Gamma$",
        "Gamma": r"$\Gamma$",
        "\\Gamma": r"$\Gamma$",
    }
    return aliases.get(label, label)


def labels_from_path_comment(comment: str) -> tuple[str, str] | None:
    if not comment:
        return None
    cleaned = comment.strip()
    cleaned = re.sub(r"\bto\b", "-", cleaned, flags=re.I)
    cleaned = cleaned.replace("->", "-").replace(" ", "")
    parts = [part for part in cleaned.split("-") if part]
    if len(parts) < 2:
        return None
    return normalize_q_label(parts[0]), normalize_q_label(parts[-1])


def parse_band_structure_ticks(control_path: Path, q_values: np.ndarray) -> tuple[list[float], list[str]]:
    if not control_path.exists() or q_values.size < 2:
        return [], []
    lines = control_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    block_index = None
    for idx, line in enumerate(lines):
        content = line.split("!", 1)[0].strip()
        if content.upper() == "BANDS_STRUCTURE":
            block_index = idx
            break
    if block_index is None:
        return [], []

    cursor = block_index + 1
    while cursor < len(lines) and not lines[cursor].split("!", 1)[0].strip():
        cursor += 1
    if cursor >= len(lines):
        return [], []
    try:
        segment_count = int(float(lines[cursor].split("!", 1)[0].split()[0]))
    except (IndexError, ValueError):
        return [], []

    npoints: list[int] = []
    label_pairs: list[tuple[str, str]] = []
    cursor += 1
    while cursor < len(lines) and len(npoints) < segment_count:
        raw_line = lines[cursor]
        content, _, comment = raw_line.partition("!")
        tokens = content.split()
        if len(tokens) >= 7:
            try:
                npoints.append(max(1, int(float(tokens[6]))))
                pair = labels_from_path_comment(comment)
                if pair:
                    label_pairs.append(pair)
            except ValueError:
                pass
        cursor += 1

    if not npoints:
        return [], []

    ticks = [float(q_values[0])]
    total = 0
    for count in npoints:
        total += count
        ticks.append(float(q_values[min(max(total - 1, 0), q_values.size - 1)]))

    if label_pairs and len(label_pairs) == len(npoints):
        labels = [label_pairs[0][0]]
        labels.extend(pair[1] for pair in label_pairs)
    else:
        labels = [f"Q{idx}" for idx in range(len(ticks))]
    return ticks, labels


def sqw_norm(values: np.ndarray, style: dict | None = None) -> Normalize:
    """Use the legacy S(Q,E) intensity scale while clipping rare spikes."""
    style = style or {}
    finite = values[np.isfinite(values)]
    if finite.size == 0:
        return Normalize(vmin=0.0, vmax=1.0)
    raw_min = float(np.nanmin(finite))
    raw_max = float(np.nanmax(finite))
    vmin = style.get("cmin")
    vmax = style.get("cmax")
    if vmin is None:
        vmin = 0.0 if raw_min >= 0.0 else float(np.nanpercentile(finite, 1.0))
    if vmax is None:
        vmax = float(np.nanpercentile(finite, 99.6))
    if vmax <= vmin:
        vmax = raw_max if raw_max > vmin else vmin + 1.0
    color_scale = style.get("color_scale") or "linear"
    gamma = style.get("gamma")
    if gamma is None or gamma <= 0.0:
        gamma = 0.55 if color_scale == "power" else 1.0
    if color_scale != "power" or abs(gamma - 1.0) < 1e-9:
        return Normalize(vmin=vmin, vmax=vmax, clip=True)
    return PowerNorm(gamma=gamma, vmin=vmin, vmax=vmax, clip=True)


def smooth_sqw_grid_for_display(matrix: np.ndarray, sigma: float = 0.45) -> np.ndarray:
    """Soften residual grid discretization without changing the source data."""
    sigma = max(0.0, float(sigma))
    if sigma <= 1e-9:
        return matrix
    energy_sigma = min(0.25, sigma * 0.55)
    if gaussian_filter is not None:
        return gaussian_filter(matrix, sigma=(energy_sigma, sigma), mode="nearest")

    radius = max(1, int(math.ceil(3.0 * sigma)))
    grid = np.arange(-radius, radius + 1, dtype=float)
    kernel = np.exp(-0.5 * (grid / sigma) ** 2)
    kernel /= kernel.sum()
    return np.apply_along_axis(lambda row: np.convolve(row, kernel, mode="same"), 1, matrix)


def plot_sqw(path: Path, plots_dir: Path, cmap: str, control_path: Path, style: dict | None = None) -> dict | None:
    style = style or {}
    data = load_numeric(path)
    if data is None or data.shape[1] < 3:
        return None
    x = data[:, 0]
    y = data[:, 1]
    z = data[:, 2]
    ux = np.unique(x)
    uy = np.unique(y)
    out = plots_dir / f"{path.stem}.png"
    fig, ax = plt.subplots(figsize=(8.0, 4.8), dpi=170)
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")
    norm = sqw_norm(z, style)
    line_width = style.get("line_width")
    display_sigma = 0.0 if line_width is None or line_width <= 0.0 else 0.45 * min(float(line_width), 3.0)
    if ux.size * uy.size == z.size:
        matrix = z.reshape(ux.size, uy.size).T
        if display_sigma > 0.0:
            matrix = smooth_sqw_grid_for_display(matrix, display_sigma)
        extent = (float(ux.min()), float(ux.max()), float(uy.min()), float(uy.max()))
        mesh = ax.imshow(
            matrix,
            aspect="auto",
            origin="lower",
            extent=extent,
            interpolation="bilinear",
            cmap=cmap,
            norm=norm,
        )
    else:
        levels = np.linspace(norm.vmin, norm.vmax, 140)
        mesh = ax.tricontourf(x, y, z, levels=levels, cmap=cmap, norm=norm, extend="max")

    if path.stem == "sqw_crystal":
        ticks, labels = parse_band_structure_ticks(control_path, ux)
        if ticks:
            if style.get("q_start_label"):
                labels[0] = style["q_start_label"]
            if style.get("q_end_label"):
                labels[-1] = style["q_end_label"]
            ax.set_xticks(ticks)
            ax.set_xticklabels(labels)
            for tick in ticks[1:-1]:
                ax.axvline(tick, color="#aeb8c5", linestyle=":", linewidth=0.9, zorder=4)
        else:
            ax.grid(True, axis="x", color="#d6dce6", linestyle=":", linewidth=0.7)

    fontdict = {
        "family": style.get("font_family") or "sans-serif",
        "size": style.get("font_size") or 12,
        "color": style.get("font_color") or "#1f2937",
        "weight": "bold" if style.get("font_bold") else "normal",
        "style": "italic" if style.get("font_italic") else "normal",
    }
    xlabel = style.get("xlabel") or ("Q path" if path.stem == "sqw_crystal" else "Q (1/A)")
    ylabel = style.get("ylabel") or "Energy (meV)"
    title = style.get("title") or (
        "Dynamic structure factor S(Q,E)" if path.stem == "sqw_crystal" else "Powder S(|Q|,E)"
    )
    ax.set_xlabel(xlabel, fontdict=fontdict)
    ax.set_ylabel(ylabel, fontdict=fontdict)
    ax.set_title(title, fontdict=fontdict)
    if style.get("xlim_min") is not None and style.get("xlim_max") is not None:
        ax.set_xlim(style["xlim_min"], style["xlim_max"])
    if style.get("ylim_min") is not None and style.get("ylim_max") is not None:
        ax.set_ylim(style["ylim_min"], style["ylim_max"])
    ax.tick_params(direction="out", length=4, width=0.8, color="#1f2937")
    for spine in ax.spines.values():
        spine.set_linewidth(0.9)
        spine.set_color("#1f2937")
    fig.colorbar(mesh, ax=ax, label="S(Q,E)", pad=0.02)
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)
    return {"kind": path.stem, "name": out.name, "path": f"plots/{out.name}"}


def plot_outputs(job_dir: Path, cmap: str) -> list[dict]:
    cmap = cmap if cmap in PLOT_CMAPS else "jet"
    plots_dir = job_dir / "plots"
    plots_dir.mkdir(exist_ok=True)
    images: list[dict] = []

    band_path = job_dir / "phononband.dat"
    dos_path = job_dir / "phonondos.dat"
    surface_path = job_dir / "phononsurface.fs"

    band_consumed = False
    surface_consumed = False

    if band_path.exists() and dos_path.exists():
        result = plot_band_dos(band_path, dos_path, plots_dir)
        if result:
            images.append(result)
            band_consumed = True
    if band_path.exists() and surface_path.exists():
        result = plot_band_isosurface(band_path, surface_path, plots_dir)
        if result:
            images.append(result)
            band_consumed = True
            surface_consumed = True

    if not band_consumed and band_path.exists():
        result = plot_band(band_path, plots_dir)
        if result:
            images.append(result)
    if not band_consumed and not band_path.exists() and dos_path.exists():
        result = plot_dos(dos_path, plots_dir)
        if result:
            images.append(result)

    if not surface_consumed and surface_path.exists():
        result = plot_isosurface(surface_path, plots_dir)
        if result:
            images.append(result)

    for filename in ["sqw_crystal.dat", "sqw_powder.dat"]:
        path = job_dir / filename
        if path.exists():
            result = plot_sqw(path, plots_dir, cmap, job_dir / "inp.control")
            if result:
                images.append(result)
    return images


def list_files(job_id: str, job_dir: Path) -> list[dict]:
    files: list[dict] = []
    for path in sorted(job_dir.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(job_dir).as_posix()
        files.append(
            {
                "name": rel,
                "size": path.stat().st_size,
                "url": f"/outputs/{job_id}/{rel}",
            }
        )
    return files


def render_existing_outputs(job_id: str, cmap: str) -> dict:
    if not re.fullmatch(r"[0-9A-Za-z_.-]+", job_id):
        return {"ok": False, "errors": ["Invalid job id"], "images": [], "files": []}
    job_dir = JOBS_DIR / job_id
    if not job_dir.exists() or not job_dir.is_dir():
        return {"ok": False, "errors": ["Job not found"], "images": [], "files": []}
    images = plot_outputs(job_dir, cmap)
    stamp = int(time.time() * 1000)
    for image in images:
        image["url"] = f"/outputs/{job_id}/{image['path']}?v={stamp}"
    return {
        "ok": True,
        "status": "rendered",
        "jobId": job_id,
        "images": images,
        "files": list_files(job_id, job_dir),
    }


def style_from_query(query: dict) -> dict:
    def text(name: str) -> str | None:
        value = query.get(name, [""])[0].strip()
        return value if value else None

    def number(name: str) -> float | None:
        value = text(name)
        if value is None:
            return None
        try:
            return float(value)
        except ValueError:
            return None

    def boolean(name: str) -> bool:
        return query.get(name, ["0"])[0].strip().lower() in ("1", "true", "on", "yes")

    return {
        "xlabel": text("xlabel"),
        "ylabel": text("ylabel"),
        "title": text("title"),
        "font_family": text("font_family"),
        "font_size": number("font_size"),
        "font_color": text("font_color"),
        "font_bold": boolean("font_bold"),
        "font_italic": boolean("font_italic"),
        "xlim_min": number("xlim_min"),
        "xlim_max": number("xlim_max"),
        "ylim_min": number("ylim_min"),
        "ylim_max": number("ylim_max"),
        "q_start_label": text("q_start_label"),
        "q_end_label": text("q_end_label"),
        "color_scale": text("color_scale"),
        "cmin": number("cmin"),
        "cmax": number("cmax"),
        "gamma": number("gamma"),
        "line_width": number("line_width"),
    }


def render_sqw_with_style(job_id: str, kind: str, style: dict, cmap: str = "turbo") -> dict:
    if not re.fullmatch(r"[0-9A-Za-z_.-]+", job_id):
        return {"ok": False, "errors": ["Invalid job id"], "image": None}
    filenames = {"sqw_crystal": "sqw_crystal.dat", "sqw_powder": "sqw_powder.dat"}
    if kind not in filenames:
        return {"ok": False, "errors": ["Unknown plot kind"], "image": None}
    job_dir = JOBS_DIR / job_id
    if not job_dir.exists() or not job_dir.is_dir():
        return {"ok": False, "errors": ["Job not found"], "image": None}
    path = job_dir / filenames[kind]
    if not path.exists():
        return {"ok": False, "errors": ["Source data not found"], "image": None}
    plots_dir = job_dir / "plots"
    plots_dir.mkdir(exist_ok=True)
    cmap = cmap if cmap in PLOT_CMAPS else "jet"
    image = plot_sqw(path, plots_dir, cmap, job_dir / "inp.control", style)
    if image is None:
        return {"ok": False, "errors": ["Failed to render plot"], "image": None}
    stamp = int(time.time() * 1000)
    image["url"] = f"/outputs/{job_id}/{image['path']}?v={stamp}"
    return {"ok": True, "image": image}


def parse_content_disposition(value: str) -> dict[str, str]:
    result: dict[str, str] = {}
    parts = [part.strip() for part in value.split(";")]
    if parts:
        result["type"] = parts[0].lower()
    for part in parts[1:]:
        if "=" not in part:
            continue
        key, raw = part.split("=", 1)
        raw = raw.strip()
        if len(raw) >= 2 and raw[0] == raw[-1] == '"':
            raw = raw[1:-1]
        result[key.strip().lower()] = raw
    return result


def parse_multipart(content_type: str, body: bytes) -> MultipartForm:
    match = re.search(r"boundary=(?P<boundary>[^;]+)", content_type)
    if not match:
        raise ValueError("Missing multipart boundary")
    boundary = match.group("boundary").strip().strip('"').encode("utf-8")
    marker = b"--" + boundary
    form = MultipartForm()

    for raw_part in body.split(marker):
        if not raw_part:
            continue
        if raw_part.startswith(b"--"):
            break
        # 去掉 boundary 标记后的 CRLF（分隔符，不属于任何字段内容）
        if raw_part.startswith(b"\r\n"):
            raw_part = raw_part[2:]
        elif raw_part.startswith(b"\n"):
            raw_part = raw_part[1:]
        if b"\r\n\r\n" not in raw_part:
            continue
        raw_headers, data = raw_part.split(b"\r\n\r\n", 1)
        # 去掉 data 末尾紧邻 boundary 的一个 CRLF/LF，保留文件内容本身的换行
        if data.endswith(b"\r\n"):
            data = data[:-2]
        elif data.endswith(b"\n"):
            data = data[:-1]
        headers: dict[str, str] = {}
        for line in raw_headers.decode("latin1", errors="replace").split("\r\n"):
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            headers[key.strip().lower()] = value.strip()
        disp = parse_content_disposition(headers.get("content-disposition", ""))
        name = disp.get("name")
        if not name:
            continue
        filename = disp.get("filename")
        if filename == "":
            filename = None
        form.add(FormField(name=name, data=data, filename=filename))
    return form


def run_job_from_form(form: MultipartForm) -> dict:
    job_id, job_dir = new_job_dir()
    workflow = normalize_workflow(field_value(form, "workflow", WORKFLOW_PLOTS))
    cmap = field_value(form, "cmap", "jet")
    saved, prep_warnings, example_id = prepare_inputs(form, job_dir, workflow)
    flags = read_control_flags(job_dir)
    errors, validation_warnings = validate_inputs(job_dir, flags, workflow)

    if errors:
        return {
            "ok": False,
            "status": "validation_failed",
            "workflow": workflow,
            "jobId": job_id,
            "example": example_id,
            "saved": saved,
            "flags": flags,
            "errors": errors,
            "warnings": prep_warnings + validation_warnings,
            "files": list_files(job_id, job_dir),
            "images": [],
        }

    timeout = int(os.environ.get("NEPHONON_TIMEOUT", "900"))
    try:
        run = run_nephonon(job_dir)
    except subprocess.TimeoutExpired as exc:
        run = {
            "returncode": -1,
            "stdout": exc.stdout or "",
            "stderr": (exc.stderr or "") + f"\nExecution timed out after {timeout} seconds.",
            "duration": timeout,
        }

    post_errors: list[str] = []
    images = []
    if workflow == WORKFLOW_FORCE_CONSTANTS:
        if run["returncode"] == 0 and not (job_dir / "FORCE_CONSTANTS").exists():
            post_errors.append("NEPHONON finished but FORCE_CONSTANTS was not generated.")
    else:
        images = plot_outputs(job_dir, cmap)

    for image in images:
        image["url"] = f"/outputs/{job_id}/{image['path']}"

    ok = run["returncode"] == 0 and not post_errors
    return {
        "ok": ok,
        "status": "finished" if ok else "failed",
        "workflow": workflow,
        "jobId": job_id,
        "example": example_id,
        "saved": saved,
        "flags": flags,
        "errors": post_errors,
        "warnings": prep_warnings + validation_warnings,
        "run": run,
        "images": images,
        "files": list_files(job_id, job_dir),
    }


class NephononHandler(BaseHTTPRequestHandler):
    server_version = "NephononWeb/0.1"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("[%s] %s\n" % (time.strftime("%H:%M:%S"), fmt % args))

    def do_GET(self) -> None:
        self.handle_get(head_only=False)

    def do_HEAD(self) -> None:
        self.handle_get(head_only=True)

    def require_page_user(self, return_to: str) -> bool:
        try:
            user = current_user(self.headers.get("Cookie"))
        except AuthError:
            user = None
        if user is not None:
            return True
        safe_return = return_to if return_to.startswith("/") and not return_to.startswith("//") else "/"
        redirect_response(self, f"/login?next={quote(safe_return, safe='')}")
        return False

    def require_api_user(self) -> bool:
        try:
            user = current_user(self.headers.get("Cookie"))
        except AuthError as exc:
            json_response(self, {"ok": False, "code": exc.code, "error": str(exc)}, exc.status)
            return False
        if user is not None:
            return True
        json_response(
            self,
            {"ok": False, "code": "authentication_required", "error": "请先登录后再使用功能模块。"},
            401,
        )
        return False

    def handle_get(self, head_only: bool = False) -> None:
        parsed = urlparse(self.path)
        route = unquote(parsed.path)
        if route == "/":
            self.serve_file(STATIC_DIR / "home.html", head_only=head_only)
            return
        if route in {"/modules", "/modules/"}:
            self.serve_file(STATIC_DIR / "modules.html", head_only=head_only)
            return
        if route in {"/login", "/register", "/account"}:
            self.serve_file(STATIC_DIR / "auth.html", head_only=head_only)
            return
        if route in {"/plots", "/force", "/force_constants"}:
            return_to = route + (f"?{parsed.query}" if parsed.query else "")
            if not self.require_page_user(return_to):
                return
            self.serve_file(STATIC_DIR / "index.html", head_only=head_only)
            return
        if route in {"/fasttrack", "/fasttrack/"}:
            if not self.require_page_user("/fasttrack/"):
                return
            configured_target = os.environ.get("FASTTRACK_FRONTEND_URL", "").strip()
            request_host = self.headers.get("Host", "").split(":", 1)[0].strip().lower()
            if configured_target:
                redirect_response(self, configured_target)
            elif request_host in {"127.0.0.1", "localhost", "::1"}:
                redirect_response(self, "http://127.0.0.1:5173/")
            else:
                text_response(self, "FastTrack reverse proxy is not configured.", 503)
            return
        if route.startswith("/static/"):
            rel = route.removeprefix("/static/")
            target = (STATIC_DIR / rel).resolve()
            try:
                target.relative_to(STATIC_DIR.resolve())
            except ValueError:
                text_response(self, "Forbidden", 403)
                return
            self.serve_file(target, head_only=head_only)
            return
        if route.startswith("/outputs/"):
            if not self.require_api_user():
                return
            parts = route.removeprefix("/outputs/").split("/", 1)
            if len(parts) != 2:
                text_response(self, "Not found", 404)
                return
            target = safe_output_path(parts[0], parts[1])
            if target is None:
                text_response(self, "Forbidden", 403)
                return
            self.serve_file(target, head_only=head_only)
            return
        if route == "/api/examples":
            if not self.require_api_user():
                return
            json_response(
                self,
                {
                    "examples": [
                        {"id": key, "name": value["name"], "description": value["description"]}
                        for key, value in EXAMPLES.items()
                    ]
                },
            )
            return
        if route == "/api/control":
            if not self.require_api_user():
                return
            query = parse_qs(parsed.query)
            workflow = normalize_workflow(query.get("workflow", [WORKFLOW_PLOTS])[0])
            example_id = query.get("example", ["zno_band"])[0]
            control = example_control_text(example_id, workflow)
            if control is None:
                json_response(self, {"ok": False, "errors": ["inp.control template not found"]}, 404)
                return
            text, name = control
            json_response(self, {"ok": True, "example": example_id, "name": name, "text": text})
            return
        if route == "/api/replot":
            if not self.require_api_user():
                return
            query = parse_qs(parsed.query)
            job_id = query.get("jobId", query.get("job", [""]))[0]
            cmap = query.get("cmap", ["jet"])[0]
            result = render_existing_outputs(job_id, cmap)
            json_response(self, result, 200 if result.get("ok") else 404)
            return
        if route == "/api/style":
            if not self.require_api_user():
                return
            query = parse_qs(parsed.query)
            job_id = query.get("jobId", query.get("job", [""]))[0]
            kind = query.get("kind", ["sqw_crystal"])[0]
            cmap = query.get("cmap", ["jet"])[0]
            style = style_from_query(query)
            result = render_sqw_with_style(job_id, kind, style, cmap)
            json_response(self, result, 200 if result.get("ok") else 404)
            return
        if route == "/api/health":
            command = nephonon_command()
            json_response(
                self,
                {
                    "ok": True,
                    "workspace": str(ROOT),
                    "command": command,
                    "commandAvailable": command_is_available(command),
                },
            )
            return
        if route == "/api/auth/status":
            json_response(self, auth_status())
            return
        if route == "/api/auth/me":
            try:
                user = current_user(self.headers.get("Cookie"))
                json_response(self, {"ok": True, "authenticated": user is not None, "user": user})
            except AuthError as exc:
                json_response(self, {"ok": False, "code": exc.code, "error": str(exc)}, exc.status)
            return
        text_response(self, "Not found", 404)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path in {"/api/auth/register", "/api/auth/login", "/api/auth/logout"}:
            self.handle_auth_post(parsed.path)
            return
        if parsed.path not in {"/api/run", "/api/cif"}:
            text_response(self, "Not found", 404)
            return
        if not self.require_api_user():
            return
        content_type = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in content_type:
            json_response(self, {"ok": False, "errors": ["Expected multipart/form-data"]}, 400)
            return
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        try:
            form = parse_multipart(content_type, body)
        except ValueError as exc:
            json_response(self, {"ok": False, "errors": [str(exc)]}, 400)
            return
        if parsed.path == "/api/cif":
            try:
                structure = parse_cif_from_form(form)
                if structure is None:
                    json_response(self, {"ok": False, "errors": ["Missing CIF file"]}, 400)
                    return
            except ValueError as exc:
                json_response(self, {"ok": False, "errors": [str(exc)]}, 422)
                return
            json_response(self, {"ok": True, "structure": structure})
            return
        result = run_job_from_form(form)
        json_response(self, result, 200 if result.get("status") != "validation_failed" else 422)

    def handle_auth_post(self, route: str) -> None:
        if not request_has_valid_origin(self):
            json_response(self, {"ok": False, "code": "invalid_origin", "error": "请求来源无效。"}, 403)
            return

        content_type = self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower()
        if content_type != "application/json":
            json_response(
                self,
                {"ok": False, "code": "invalid_content_type", "error": "Expected application/json."},
                415,
            )
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_JSON_BYTES:
            json_response(self, {"ok": False, "code": "invalid_body", "error": "请求内容无效。"}, 400)
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("JSON object required")
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            json_response(self, {"ok": False, "code": "invalid_json", "error": "JSON 格式无效。"}, 400)
            return

        ip_address = self.client_address[0] if self.client_address else None
        user_agent = self.headers.get("User-Agent")
        secure_cookie = request_uses_https(self)
        try:
            if route == "/api/auth/register":
                user, token = register_user(payload, ip_address, user_agent)
                json_response(
                    self,
                    {"ok": True, "authenticated": True, "user": user},
                    201,
                    {"Set-Cookie": session_cookie(token, secure_cookie)},
                )
                return
            if route == "/api/auth/login":
                user, token = authenticate_user(payload, ip_address, user_agent)
                json_response(
                    self,
                    {"ok": True, "authenticated": True, "user": user},
                    200,
                    {"Set-Cookie": session_cookie(token, secure_cookie)},
                )
                return
            logout_user(self.headers.get("Cookie"))
            json_response(
                self,
                {"ok": True, "authenticated": False},
                200,
                {"Set-Cookie": clear_session_cookie(secure_cookie)},
            )
        except AuthError as exc:
            json_response(self, {"ok": False, "code": exc.code, "error": str(exc)}, exc.status)
        except Exception as exc:
            self.log_error("Authentication error: %s", exc)
            json_response(
                self,
                {"ok": False, "code": "auth_unavailable", "error": "账户服务暂时不可用。"},
                503,
            )

    def serve_file(self, path: Path, head_only: bool = False) -> None:
        if not path.exists() or not path.is_file():
            text_response(self, "Not found", 404)
            return
        mime, _ = mimetypes.guess_type(str(path))
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mime or "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if not head_only:
            self.wfile.write(body)


def main() -> None:
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8765"))
    if len(sys.argv) > 1:
        port = int(sys.argv[1])
    command = nephonon_command()
    if not command_is_available(command):
        raise SystemExit(f"Cannot find nephonon command: {' '.join(command)}")
    server = ThreadingHTTPServer((host, port), NephononHandler)
    print(f"NEPHONON Web is running at http://{host}:{port}")
    print(f"Workspace: {ROOT}")
    print(f"NEPHONON command: {' '.join(command)}")
    try:
        auth_database = ensure_auth_schema()
        print(f"Authentication database: MySQL/{auth_database['database']} (ready)")
    except AuthUnavailable as exc:
        print(f"Authentication database: unavailable ({exc})", file=sys.stderr)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
