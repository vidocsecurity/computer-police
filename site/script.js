// Computer Police — landing site. Zero dependencies, vanilla JS.
//
//  1. Copy-to-clipboard buttons for install commands.
//  2. Theme toggle (light <-> dark), persisted to localStorage as "cp-theme".
//
// Initial theme is applied synchronously in <head> (in index.html) so the page
// never flashes the wrong palette. This file only handles the click toggle.

(function () {
  "use strict";

  // ── 1. Copy-to-clipboard ───────────────────────────────────────────────────

  function copy(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var el = document.createElement("textarea");
      el.value = text;
      el.setAttribute("readonly", "");
      el.style.position = "absolute";
      el.style.left = "-9999px";
      document.body.appendChild(el);
      el.select();
      try {
        document.execCommand("copy");
        resolve();
      } catch (err) {
        reject(err);
      } finally {
        document.body.removeChild(el);
      }
    });
  }

  function flashCopied(btn) {
    var original = btn.textContent;
    btn.setAttribute("data-copied", "true");
    btn.textContent = "Copied";
    setTimeout(function () {
      btn.removeAttribute("data-copied");
      btn.textContent = original;
    }, 1500);
  }

  document.querySelectorAll(".copy-btn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var text = "";

      // Tabbed install block: copy the currently visible panel.
      var tabsKey = btn.getAttribute("data-copy-tabs");
      if (tabsKey) {
        var container = document.querySelector(
          '[data-install-tabs="' + tabsKey + '"]'
        );
        if (container) {
          var active = container.querySelector(".install-panel.is-active");
          if (active) text = active.innerText.trim();
        }
      } else {
        var targetId = btn.getAttribute("data-copy-target");
        var target = targetId ? document.getElementById(targetId) : null;
        if (target) text = target.innerText.trim();
      }

      if (!text) return;
      copy(text).then(
        function () {
          flashCopied(btn);
        },
        function () {
          btn.textContent = "Press Ctrl+C";
        }
      );
    });
  });

  // ── 1b. Install tab switching ──────────────────────────────────────────────

  document
    .querySelectorAll(".install-tabs")
    .forEach(function (container) {
      var tabs = container.querySelectorAll(".install-tab");
      var panels = container.querySelectorAll(".install-panel");

      function activate(name, focus) {
        tabs.forEach(function (t) {
          var isActive = t.getAttribute("data-tab") === name;
          t.classList.toggle("is-active", isActive);
          t.setAttribute("aria-selected", isActive ? "true" : "false");
          t.setAttribute("tabindex", isActive ? "0" : "-1");
          if (isActive && focus) t.focus();
        });
        panels.forEach(function (p) {
          var isActive = p.getAttribute("data-panel") === name;
          p.classList.toggle("is-active", isActive);
          if (isActive) {
            p.removeAttribute("hidden");
          } else {
            p.setAttribute("hidden", "");
          }
        });
      }

      tabs.forEach(function (tab, idx) {
        tab.addEventListener("click", function () {
          activate(tab.getAttribute("data-tab"), false);
        });

        tab.addEventListener("keydown", function (ev) {
          if (ev.key !== "ArrowRight" && ev.key !== "ArrowLeft") return;
          ev.preventDefault();
          var dir = ev.key === "ArrowRight" ? 1 : -1;
          var next = tabs[(idx + dir + tabs.length) % tabs.length];
          activate(next.getAttribute("data-tab"), true);
        });
      });
    });

  // ── 2. Theme toggle ────────────────────────────────────────────────────────

  var toggle = document.getElementById("theme-toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      var current = document.documentElement.getAttribute("data-theme") || "light";
      var next = current === "dark" ? "light" : "dark";
      document.documentElement.setAttribute("data-theme", next);
      try {
        localStorage.setItem("cp-theme", next);
      } catch (e) {
        // localStorage may be disabled (private mode, etc.) — toggle still works
        // for the current page view, just won't persist.
      }
      toggle.setAttribute(
        "aria-label",
        next === "dark" ? "Switch to light mode" : "Switch to dark mode"
      );
    });
  }
})();
