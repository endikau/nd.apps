// Simple streaming UI handlers for chat output
(() => {
  function ensureEl() {
    return document.getElementById("chat_stream");
  }

  const decoder = new TextDecoder();

  function escapeHTML(str) {
    return (str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function filterSourcesByCitations(sources, answerText) {
    if (!sources || !Array.isArray(sources) || sources.length === 0) return [];
    const cited = new Set();
    const regex = /\[([^\]]+)\]/g;
    let match;
    while ((match = regex.exec(answerText || "")) !== null) {
      const ids = (match[1] || "")
        .split(",")
        .map((s) => s.trim())
        .filter((s) => /^\d+$/.test(s));
      ids.forEach((id) => cited.add(id));
    }
    return sources.filter((s) => cited.has(String(s.i)));
  }

  let chatLog = [];
  const maxEntries = 20; // 10 Q&A pairs

  function buildSourceTooltipHtml(src) {
    const sanitize = (str) => (str || "").replace(/[\r\n\t\f\v]+/g, " ").trim();
    const label = sanitize(src.source_file || src.label || "Unbekannt");
    const pages = src.page_numbers && src.page_numbers.length ? `Seiten: ${src.page_numbers.join(", ")}` : "";
    const heading =
      src.headings && Array.isArray(src.headings) && src.headings.length
        ? `Abschnitt: ${sanitize(src.headings[src.headings.length - 1])}`
        : "";
    const body = sanitize(src.context_text || src.snippet || "");
    const parts = [label, pages, heading, body].filter((p) => p && p.length > 0);
    return parts.map((p) => `<div>${escapeHTML(p)}</div>`).join("");
  }

  function escapeAttr(str) {
    return (str || "").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  function annotateAnswerWithSources(answerText, sources) {
    const filtered = filterSourcesByCitations(sources, answerText);
    if (!filtered.length) {
      return escapeHTML(answerText || "").replace(/\n/g, "<br>");
    }
    const byId = new Map(filtered.map((s) => [String(s.i), s]));
    const regex = /\[([^\]]+)\]/g;
    let lastIndex = 0;
    let out = "";
    let m;
    while ((m = regex.exec(answerText || "")) !== null) {
      const [full, id] = m;
      const start = m.index;
      out += escapeHTML(answerText.slice(lastIndex, start));
      const ids = (id || "")
        .split(",")
        .map((s) => s.trim())
        .filter((s) => /^\d+$/.test(s));
      if (ids.length === 0) {
        out += escapeHTML(full);
      } else {
        const rendered = ids
          .map((oneId, idx) => {
            const src = byId.get(oneId);
            const inner = escapeHTML(oneId);
            if (!src) return inner;
            const html = buildSourceTooltipHtml(src);
            const attr = escapeAttr(html);
            return `<span class="source-ref" data-bs-toggle="tooltip" data-bs-placement="top" data-bs-html="true" title="${attr}">${inner}</span>`;
          })
          .join(", ");
        out += `[${rendered}]`;
      }
      lastIndex = m.index + full.length;
    }
    out += escapeHTML(answerText.slice(lastIndex));
    return out.replace(/\n/g, "<br>");
  }

  function initTooltips(container) {
    if (typeof bootstrap === "undefined" || !container) return;
    const els = container.querySelectorAll('[data-bs-toggle="tooltip"]');
    els.forEach((el) => {
      try {
        new bootstrap.Tooltip(el, {
          container: "body",
          boundary: "window",
          placement: "auto",
          html: true,
          trigger: "hover focus"
        });
      } catch (e) {
        // ignore tooltip init errors
      }
    });
  }

  function streamChat(cfg) {
    const el = ensureEl();
    if (!el) return;
    el.textContent = "";
    let answerText = "";
    let currentSources = [];

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
    if (cfg.system_prompt) bodyObj.system_prompt = cfg.system_prompt;
    if (cfg.condense_prompt) bodyObj.condense_prompt = cfg.condense_prompt;
    if (cfg.context_prompt) bodyObj.context_prompt = cfg.context_prompt;
    if (cfg.context_refine_prompt) bodyObj.context_refine_prompt = cfg.context_refine_prompt;
    if (cfg.response_prompt) bodyObj.response_prompt = cfg.response_prompt;
    if (cfg.citation_qa_template) bodyObj.citation_qa_template = cfg.citation_qa_template;
    if (cfg.citation_refine_template) bodyObj.citation_refine_template = cfg.citation_refine_template;

    function renderLog() {
      const html = chatLog
        .map((m) => {
          const roleLabel = m.role === "user" ? "You" : "Assistant";
          let htmlText;
          if (m.raw === true) {
            htmlText = m.text || "";
          } else {
            const rendered =
              m.role === "assistant"
                ? annotateAnswerWithSources(m.text || "", m.sources || [])
                : escapeHTML(m.text || "");
            htmlText =
              typeof marked !== "undefined"
                ? marked.parse(rendered, { breaks: true, gfm: true })
                : rendered.replace(/\n/g, "<br>");
          }
          const bubbleClass = m.role === "user" ? "chat-bubble user" : "chat-bubble assistant";
          return `<div class="chat-row ${m.role}"><div class="${bubbleClass}"><div class="chat-role">${roleLabel}</div><div class="chat-text">${htmlText}</div></div></div>`;
        })
        .join("");
      el.innerHTML = html;
      el.scrollTop = el.scrollHeight;
      initTooltips(el);
    }

    function pushMessage(role, text, opts = {}) {
      chatLog.push({ role, text, sources: [], raw: opts.raw === true });
      if (chatLog.length > maxEntries) {
        chatLog = chatLog.slice(chatLog.length - maxEntries);
      }
      renderLog();
    }

    // add user message and placeholder assistant entry
    pushMessage("user", cfg.message || "");
    pushMessage("assistant", "");
    const assistantIdx = chatLog.length - 1;

    const notifyError = (msg) => {
      Shiny.setInputValue("chat_error", { error: msg }, { priority: "event" });
    };

    // Show a loading indicator inside the assistant placeholder
    const loadingId = `loading-${Date.now()}`;
    chatLog[assistantIdx] = {
      role: "assistant",
      text: `<span class="loading-brain" id="${loadingId}"><i class="fa-solid fa-brain fa-pulse"></i></span> Denke nach...`,
      sources: [],
      raw: true
    };
    renderLog();

    fetch(url, { method: "POST", headers, body: JSON.stringify(bodyObj) })
      .then((resp) => {
        if (!resp.ok || !resp.body) {
          const err = `HTTP ${resp.status}`;
          notifyError(err);
          chatLog[assistantIdx].text = "(request failed; see notification)";
          renderLog();
          return;
        }
        const reader = resp.body.getReader();
        let buffer = "";

        function pump() {
          return reader.read().then(({ done, value }) => {
            if (done) return;
            buffer += decoder.decode(value || new Uint8Array(), { stream: true });
            let idx;
            while ((idx = buffer.indexOf("\n")) >= 0) {
              const line = buffer.slice(0, idx);
              buffer = buffer.slice(idx + 1);
              if (!line.trim()) continue;
              try {
                const chunk = JSON.parse(line);
                if (chunk.type === "token") {
                  answerText += chunk.delta || "";
                  chatLog[assistantIdx].text = answerText;
                  chatLog[assistantIdx].sources = currentSources;
                  chatLog[assistantIdx].raw = false;
                  renderLog();
                } else if (chunk.type === "sources") {
                  currentSources = chunk.sources || [];
                  chatLog[assistantIdx].sources = currentSources;
                  renderLog();
                } else if (chunk.type === "done") {
                  if (chunk.answer) answerText = chunk.answer;
                  if (chunk.sources) currentSources = chunk.sources;
                  chatLog[assistantIdx].text = answerText;
                  chatLog[assistantIdx].sources = currentSources;
                  chatLog[assistantIdx].raw = false;
                  renderLog();
                  Shiny.setInputValue(
                    "chat_result",
                    { answer: chunk.answer || el.textContent, sources: chunk.sources || [] },
                    { priority: "event" }
                  );
                } else if (chunk.type === "error") {
                  notifyError(chunk.error || "unknown");
                  chatLog[assistantIdx].text = "(request failed; see notification)";
                  renderLog();
                  return;
                }
              } catch (e) {
                notifyError(String(e));
                chatLog[assistantIdx].text = "(request failed; see notification)";
                renderLog();
              }
            }
            return pump();
          }).catch((err) => {
            notifyError(String(err));
            chatLog[assistantIdx].text = "(request failed; see notification)";
            renderLog();
          });
        }

        return pump();
      })
      .catch((err) => {
        notifyError(String(err));
        chatLog[assistantIdx].text = "(request failed; see notification)";
        renderLog();
      });
  }

  Shiny.addCustomMessageHandler("chat-start", (cfg) => {
    streamChat(cfg || {});
  });

  // Submit on Enter inside the question input
  document.addEventListener("keypress", (evt) => {
    const tgt = evt.target;
    if (!tgt || tgt.id !== "question") return;
    const val = tgt.value || "";
    if (evt.key === "Enter" && val.trim().length > 0) {
      const btn = document.getElementById("send_btn");
      if (btn) {
        btn.click();
        evt.preventDefault();
      }
    }
  });

  // Legacy handlers retained as no-ops to avoid JS errors if triggered
  Shiny.addCustomMessageHandler("chat-reset", () => {});
  Shiny.addCustomMessageHandler("chat-delta", () => {});
  Shiny.addCustomMessageHandler("chat-done", () => {});
  Shiny.addCustomMessageHandler("chat-set", () => {});
  Shiny.addCustomMessageHandler("chat-error", () => {});
})();
