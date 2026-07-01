// Synchronisiert die Dokumentenliste zwischen separat eingebetteten Bausteinen.
// Die iframes laufen im selben Origin und teilen sich über die URL dieselbe
// session_id – daher können sie direkt per BroadcastChannel kommunizieren
// (ereignisbasiert statt Polling, kein Parent-Relay nötig). Nur aktiv, wenn eine
// session_id in der URL steht, also im geteilten Einbettungsfall.
(() => {
  const params = new URLSearchParams(window.location.search);
  const sessionId = params.get("session_id");
  if (!sessionId) return;

  const element = (params.get("ui_element") || "").toLowerCase();
  const channel = new BroadcastChannel("rag-docs-" + sessionId);

  // Dokumente-Baustein: auf abgeschlossene Ingests aus anderen Bausteinen
  // reagieren und die Liste neu laden lassen.
  if (element === "documents") {
    channel.addEventListener("message", (event) => {
      if (event.data && event.data.type === "ingested") {
        Shiny.setInputValue("external_refresh", Date.now(), { priority: "event" });
      }
    });
  }

  // Baustein mit Ingest: der Server erhöht bei jedem abgeschlossenen Ingest das
  // versteckte Output `ingest_version`. Dessen Textänderung im DOM wird per
  // MutationObserver erkannt und in eine Broadcast-Nachricht umgesetzt. (Bewusst
  // kein Shiny-/jQuery-Event, da nd_app und Shiny je eine eigene jQuery-Instanz
  // laden und deren Events sich nicht gegenseitig erreichen.)
  const watchVersion = () => {
    const el = document.getElementById("ingest_version");
    if (!el) return;
    let last = (el.textContent || "").trim();
    new MutationObserver(() => {
      const value = (el.textContent || "").trim();
      if (value === last) return;
      last = value;
      if (Number(value) > 0) {
        channel.postMessage({ type: "ingested" });
      }
    }).observe(el, { childList: true, characterData: true, subtree: true });
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", watchVersion);
  } else {
    watchVersion();
  }
})();
