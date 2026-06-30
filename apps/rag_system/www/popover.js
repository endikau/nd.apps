// Popover-Engine, abgeleitet aus @endikau/nd_assets dist/js/popover.js.
// Unterschied: Die Asset-Version initialisiert Popovers nur einmal bei
// DOMContentLoaded. Shiny rendert den Chat dynamisch nach, daher ist die Logik
// hier zu window.ndInitPopovers(root) umgebaut und pro Trigger idempotent
// (data-nd-popover-init), die globalen Schließen-Handler werden genau einmal
// gebunden. Aufgerufen wird sie aus chatUi.js bei jedem Re-Render.
(function () {
  let openTrigger = null;
  let pinned = false;
  let hideTimer = null;
  let globalBound = false;
  const canHover = window.matchMedia("(hover: hover)").matches;
  const popTemplate =
    '<div class="popover nd-popover" role="tooltip"><div class="popover-arrow"></div><h3 class="popover-header"></h3><div class="popover-body"></div></div>';

  function clearHideTimer() {
    if (hideTimer) {
      clearTimeout(hideTimer);
      hideTimer = null;
    }
  }

  function ensureHeaderCloseButton(popEl) {
    const header = popEl.querySelector(".popover-header");
    if (!header) return;
    if (header.querySelector(".nd-close")) return;
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "btn nd-close p-0 border-0 bg-transparent text-primary";
    btn.role = "button";
    btn.setAttribute("aria-label", "Close");
    btn.innerHTML = '<i class="fa-solid fa-xmark"></i>';
    header.appendChild(btn);
  }

  function initOne(el) {
    if (typeof bootstrap === "undefined") return;
    if (el.dataset.ndPopoverInit === "1") return;
    el.dataset.ndPopoverInit = "1";
    bootstrap.Popover.getInstance(el)?.dispose();
    const tplId = el.getAttribute("data-bs-template-id");
    const tpl = tplId ? document.getElementById(tplId) : null;
    const pop = new bootstrap.Popover(el, {
      trigger: "manual",
      html: true,
      sanitize: false,
      container: "body",
      template: popTemplate,
      title: el.getAttribute("data-bs-title") || "",
      content: function () {
        return tpl ? tpl.innerHTML : "";
      }
    });

    function scheduleHide() {
      if (pinned) return;
      clearHideTimer();
      hideTimer = setTimeout(function () {
        if (openTrigger === el && !pinned) {
          pop.hide();
          openTrigger = null;
        }
      }, 200);
    }

    function showPop(pin) {
      clearHideTimer();
      if (openTrigger && openTrigger !== el) {
        bootstrap.Popover.getInstance(openTrigger)?.hide();
        pinned = false;
      }
      if (openTrigger !== el) {
        pop.show();
        openTrigger = el;
        const popId = el.getAttribute("aria-describedby");
        const popEl = popId ? document.getElementById(popId) : null;
        if (popEl) {
          ensureHeaderCloseButton(popEl);
          if (canHover) {
            popEl.addEventListener("mouseenter", clearHideTimer);
            popEl.addEventListener("mouseleave", scheduleHide);
          }
        }
      }
      if (pin) pinned = true;
    }

    el.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      clearHideTimer();
      if (openTrigger === el) {
        pop.hide();
        openTrigger = null;
        pinned = false;
        return;
      }
      showPop(true);
    });
    if (canHover) {
      el.addEventListener("mouseenter", function () {
        showPop(false);
      });
      el.addEventListener("mouseleave", scheduleHide);
      el.addEventListener("focus", function () {
        showPop(false);
      });
    }
  }

  function bindGlobalOnce() {
    if (globalBound) return;
    globalBound = true;
    document.addEventListener("click", function (e) {
      const closeBtn = e.target.closest(".nd-close");
      if (closeBtn) {
        const popEl = closeBtn.closest(".popover");
        const trigger = document.querySelector('[aria-describedby="' + popEl.id + '"]');
        bootstrap.Popover.getInstance(trigger)?.hide();
        openTrigger = null;
        pinned = false;
        clearHideTimer();
        return;
      }
      if (e.target.closest(".nd-popover")) return;
      if (e.target.closest('[data-bs-toggle="popover"]')) return;
      if (openTrigger) {
        bootstrap.Popover.getInstance(openTrigger)?.hide();
        openTrigger = null;
        pinned = false;
        clearHideTimer();
      }
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && openTrigger) {
        bootstrap.Popover.getInstance(openTrigger)?.hide();
        openTrigger = null;
        pinned = false;
        clearHideTimer();
      }
    });
  }

  // Initialisiert alle noch nicht initialisierten Popover-Trigger in `root`.
  window.ndInitPopovers = function (root) {
    if (typeof bootstrap === "undefined") return;
    bindGlobalOnce();
    (root || document).querySelectorAll('[data-bs-toggle="popover"]').forEach(initOne);
  };

  document.addEventListener("DOMContentLoaded", function () {
    window.ndInitPopovers(document);
  });
})();
