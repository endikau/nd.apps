// Chat-Streaming für die RAG-App.
//
// Das Rendering der Chat-Blasen passiert serverseitig in R (mit den aus der
// Fallstudie übernommenen Helfern). Dieses Skript übernimmt nur das eigentliche
// Streaming vom RAG-Service und leitet den Text an R weiter – und zwar nur in
// vollständigen Absätzen (bis zum letzten "\n\n"), damit R jeden Absatz fertig
// stylen kann, bevor er erscheint. Der unfertige letzte Absatz wird
// zurückgehalten, bis er abgeschlossen ist bzw. das finale "done" eintrifft.
(() => {
  const decoder = new TextDecoder();

  function streamChat(cfg) {
    const url = (cfg.base_url || "").replace(/\/$/, "") + "/chat/stream";
    const headers = {
      "Content-Type": "application/json",
      "X-Session-Id": cfg.session_id || ""
    };
    if (cfg.api_key) headers["X-Api-Key"] = cfg.api_key;

    const bodyObj = {
      message: cfg.message || "",
      history: cfg.history || []
    };
    if (cfg.include_trace === true) bodyObj.include_trace = true;
    [
      "system_prompt",
      "condense_prompt",
      "context_prompt",
      "context_refine_prompt",
      "response_prompt",
      "citation_qa_template",
      "citation_refine_template"
    ].forEach((k) => {
      if (cfg[k]) bodyObj[k] = cfg[k];
    });

    let answerText = "";
    let sources = [];
    let lastStable = "";

    const notifyError = (msg) => {
      console.error("[rag_system] Chat-Fehler:", msg);
      Shiny.setInputValue("chat_error", { error: msg }, { priority: "event" });
    };

    // Stabilen (absatzvollständigen) Präfix an R schicken, sobald er sich ändert.
    const sendProgress = () => {
      const idx = answerText.lastIndexOf("\n\n");
      const stable = idx === -1 ? "" : answerText.slice(0, idx);
      if (stable !== lastStable) {
        lastStable = stable;
        Shiny.setInputValue(
          "chat_progress",
          { answer: stable, sources: sources },
          { priority: "event" }
        );
      }
    };

    fetch(url, { method: "POST", headers, body: JSON.stringify(bodyObj) })
      .then((resp) => {
        if (!resp.ok || !resp.body) {
          notifyError("HTTP " + resp.status);
          return;
        }
        const reader = resp.body.getReader();
        let buffer = "";

        function pump() {
          return reader
            .read()
            .then(({ done, value }) => {
              if (done) return;
              buffer += decoder.decode(value || new Uint8Array(), { stream: true });
              let idx;
              while ((idx = buffer.indexOf("\n")) >= 0) {
                const line = buffer.slice(0, idx);
                buffer = buffer.slice(idx + 1);
                if (!line.trim()) continue;
                let chunk;
                try {
                  chunk = JSON.parse(line);
                } catch (e) {
                  notifyError(String(e));
                  return;
                }
                if (chunk.type === "token") {
                  answerText += chunk.delta || "";
                  sendProgress();
                } else if (chunk.type === "sources") {
                  sources = chunk.sources || [];
                  sendProgress();
                } else if (chunk.type === "done") {
                  if (chunk.answer) answerText = chunk.answer;
                  if (chunk.sources) sources = chunk.sources;
                  Shiny.setInputValue(
                    "chat_result",
                    {
                      answer: answerText,
                      sources: sources,
                      prompts: chunk.prompts || null,
                      trace: chunk.trace || null
                    },
                    { priority: "event" }
                  );
                } else if (chunk.type === "error") {
                  notifyError(chunk.error || "unknown");
                  return;
                }
              }
              return pump();
            })
            .catch((err) => notifyError(String(err)));
        }

        return pump();
      })
      .catch((err) => notifyError(String(err)));
  }

  Shiny.addCustomMessageHandler("chat-start", (cfg) => streamChat(cfg || {}));

  // Nach jedem serverseitigen Re-Render: Popovers (neu) initialisieren und ans
  // Ende scrollen.
  function setupChatObserver() {
    const target = document.getElementById("chat_dialogue");
    if (!target) return;
    const refresh = () => {
      if (window.ndInitPopovers) window.ndInitPopovers(target);
      // Neueste Nachricht sanft in den sichtbaren Bereich holen (Seiten-Scroll),
      // nur falls sie nicht ohnehin sichtbar ist.
      const last = target.lastElementChild;
      if (last && last.scrollIntoView) last.scrollIntoView({ block: "nearest" });
    };
    new MutationObserver(refresh).observe(target, { childList: true, subtree: true });
    refresh();
  }

  // Absenden per Enter im Frage-Feld.
  document.addEventListener("keypress", (evt) => {
    const tgt = evt.target;
    if (!tgt || tgt.id !== "question") return;
    if (evt.key === "Enter" && (tgt.value || "").trim().length > 0) {
      const btn = document.getElementById("send_btn");
      if (btn) {
        btn.click();
        evt.preventDefault();
      }
    }
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setupChatObserver);
  } else {
    setupChatObserver();
  }
})();
