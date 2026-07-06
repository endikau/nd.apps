// Zurücksetzen des PDF-fileInput nach erfolgreichem Ingest. Shiny bietet kein
// updateFileInput(), daher hier clientseitig: nativer Input, Dateinamen-Anzeige
// und Fortschrittsbalken werden geleert und der Shiny-Inputwert über den
// "shiny.file"-Typ-Handler auf NULL gesetzt (dessen Serverseite NULL durchreicht).
(() => {
  Shiny.addCustomMessageHandler("rag-reset-file-input", (id) => {
    const input = document.getElementById(id);
    if (!input) return;
    input.value = "";
    const group = input.closest(".input-group");
    const display = group && group.querySelector("input[type='text']");
    if (display) display.value = "";
    const progress = document.getElementById(id + "_progress");
    if (progress) {
      progress.style.visibility = "";
      const bar = progress.querySelector(".progress-bar");
      if (bar) {
        bar.style.width = "0";
        bar.textContent = "";
      }
    }
    Shiny.setInputValue(id + ":shiny.file", null);
  });
})();
