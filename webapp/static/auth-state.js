(function () {
  var authRequest = null;

  function loadAccount(refresh) {
    if (refresh) authRequest = null;
    if (!authRequest) {
      authRequest = fetch("/api/auth/me", {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      })
        .then(function (response) {
          if (!response.ok) return { authenticated: false, user: null };
          return response.json();
        })
        .catch(function () {
          return { authenticated: false, user: null };
        });
    }
    return authRequest;
  }

  function loginUrlFor(entry) {
    var requested = entry.getAttribute("data-auth-next");
    if (!requested) {
      try {
        var target = new URL(entry.href, window.location.href);
        requested = target.origin === window.location.origin
          ? target.pathname + target.search + target.hash
          : "/modules";
      } catch (_error) {
        requested = "/modules";
      }
    }
    if (!requested.startsWith("/") || requested.startsWith("//")) requested = "/modules";
    return "/login?next=" + encodeURIComponent(requested);
  }

  function protectFeatureEntries() {
    document.addEventListener("click", function (event) {
      var entry = event.target.closest("a[data-auth-required]");
      if (!entry) return;
      event.preventDefault();
      var destination = entry.href;
      loadAccount(true).then(function (result) {
        if (result.authenticated && result.user) {
          window.location.href = destination;
        } else {
          window.location.href = loginUrlFor(entry);
        }
      });
    });
  }

  function updateAccountLinks() {
    var entries = Array.from(document.querySelectorAll("[data-auth-entry]"));
    if (!entries.length) return;
    loadAccount().then(function (result) {
      if (!result.authenticated || !result.user) return;
      entries.forEach(function (entry) {
        entry.textContent = result.user.displayName || "我的账户";
        entry.href = "/account";
        entry.setAttribute("aria-label", window.PlatformI18n ? window.PlatformI18n.t("我的账户") : "我的账户");
      });
    });
  }

  protectFeatureEntries();
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", updateAccountLinks);
  } else {
    updateAccountLinks();
  }
})();
