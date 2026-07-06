tags <- htmltools::tags

# Gemeinsamer Stil für die Block-Buttons in den Card-Footern (wie senti_dict):
# oben eckig, unten mit dem Card-Radius abschließend.
BTN_FOOTER_STYLE <- paste0(
  "border: 0; ",
  "border-top-left-radius: 0; ",
  "border-top-right-radius: 0; ",
  "border-bottom-right-radius: var(--bs-border-radius); ",
  "border-bottom-left-radius: var(--bs-border-radius);"
)

# Block-Button im Stil von nd.util::nd_button_block, aber mit steuerbarem
# auto_reset: nd_button_block reicht benannte Zusatzargumente als
# HTML-Attribute weiter, sodass auto_reset dort nicht ankommt. Die
# asynchronen Aktionen (Ingest, Chat) setzen auto_reset=FALSE und werden
# serverseitig per bslib::update_task_button() zurückgesetzt.
rag_button_block <- function(
  .id, .label, .fa_class, .fa_class_busy = .fa_class, .auto_reset = TRUE, ...
) {
  bslib::input_task_button(
    id = .id,
    class = "btn btn-primary btn-lg btn-block text-white",
    label = .label,
    icon = tags$i(class = .fa_class, role = "presentation"),
    label_busy = .label,
    icon_busy = tags$i(class = .fa_class_busy, role = "presentation"),
    auto_reset = .auto_reset,
    style = BTN_FOOTER_STYLE,
    ...
  )
}

# Die drei Bausteine als eigenständige Cards, damit sie einzeln oder gemeinsam
# ausgeliefert werden können (Auswahl über den Query-Parameter `ui_element`).
ingest_card <- tags$div(
  class = "card",
  tags$div(class = "card-header", "Ingest"),
  tags$div(
    class = "card-body",
    div(
      class = "ingest-tabs",
      radioButtons(
        "ingest_mode",
        label = NULL,
        choices = c("PDF", "URL"),
        selected = "PDF",
        inline = TRUE
      )
    ),
    conditionalPanel(
      condition = "input.ingest_mode == 'PDF'",
      div(
        class = "ingest-file",
        fileInput(
          "pdfs",
          paste0("PDF auswählen (max. ", MAX_UPLOAD_MB, " MB)"),
          multiple = FALSE,
          accept = ".pdf",
          buttonLabel = tags$i(
            class = "fa-solid fa-file-pdf", role = "presentation"
          )
        )
      )
    ),
    conditionalPanel(
      condition = "input.ingest_mode == 'URL'",
      textInput(
        "urls",
        "Eine URL einfügen",
        value = "",
        placeholder = "https://example.com/page"
      ),
      # Unsichtbarer Platzhalter in der Höhe des Upload-Fortschrittsbalkens,
      # den fileInput() im PDF-Tab reserviert – so sind beide Tabs gleich hoch.
      tags$div(
        class = "progress shiny-file-input-progress",
        `aria-hidden` = "true",
        tags$div(class = "progress-bar")
      )
    ),
    textInput(
      "doc_name",
      "Dokumentname (optional)",
      ""
    ),
    uiOutput("ingest_progress"),
    # Verstecktes Signal-Output für die Baustein-übergreifende Synchronisation.
    tags$div(style = "display: none;", textOutput("ingest_version"))
  ),
  tags$div(
    class = "card-footer p-0 d-grid",
    rag_button_block(
      .id = "ingest_btn",
      .label = "Ingest starten",
      .fa_class = "fa-solid fa-file-import",
      .fa_class_busy = "fa-solid fa-sync fa-spin",
      .auto_reset = FALSE
    )
  )
)

# Die Dokumentenliste aktualisiert sich automatisch (nach Ingest, Löschen und
# via BroadcastChannel aus anderen Bausteinen), daher ohne eigenen Button.
documents_card <- tags$div(
  class = "card",
  tags$div(class = "card-header", "Dokumente"),
  tags$div(
    class = "card-body p-0",
    uiOutput("doc_list")
  )
)

chat_card <- tags$div(
  class = "card",
  tags$div(class = "card-header", "Chat"),
  tags$div(
    class = "card-body",
    div(
      class = "rag-chat",
      uiOutput("chat_dialogue")
    )
  ),
  tags$div(
    class = "form-group shiny-input-container m-0",
    style = "width: 100%;",
    tags$textarea(
      id = "question",
      class = "shiny-input-textarea form-control",
      style = paste0(
        "width: 100%; resize: none; border: 0; border-radius: 0; ",
        "border-top: var(--bs-border-width) solid var(--bs-border-color); ",
        "padding: 8px 16px;"
      ),
      rows = "2",
      spellcheck = "false",
      placeholder = "Frage eingeben …"
    )
  ),
  tags$div(
    class = "card-footer p-0 d-grid",
    rag_button_block(
      .id = "send_btn",
      .label = "Senden",
      .fa_class = "fa-solid fa-paper-plane",
      .fa_class_busy = "fa-solid fa-sync fa-spin",
      .auto_reset = FALSE
    )
  )
)

# Zuordnung Query-Wert -> Baustein.
UI_ELEMENTS <- list(
  ingest = ingest_card,
  documents = documents_card,
  chat = chat_card
)

# UI als Funktion des Requests, damit `ui_element` aus der URL-Query gelesen
# werden kann. Fehlt der Parameter (oder ist unbekannt), werden – wie bisher –
# alle drei Bausteine angezeigt.
ui <- function(request) {
  query <- shiny::parseQueryString(request$QUERY_STRING %||% "")
  requested <- tolower(trimws(query$ui_element %||% ""))

  blocks <- if (nzchar(requested) && !is.null(UI_ELEMENTS[[requested]])) {
    list(UI_ELEMENTS[[requested]])
  } else {
    list(ingest_card, documents_card, chat_card)
  }

  nd.util::nd_app(
    .title = "RAG-System",
    .head = tagList(
      shiny::includeCSS("www/style.css"),
      tags$style(htmltools::HTML(CHAT_CSS)),
      # Re-init-fähige Popover-Engine (für dynamisch gerenderte Chat-Inhalte),
      # Chat-Streaming und Dokumenten-Synchronisation zwischen den Bausteinen.
      shiny::includeScript("www/popover.js"),
      shiny::includeScript("www/chatUi.js"),
      shiny::includeScript("www/ingestUi.js"),
      shiny::includeScript("www/docsync.js")
    ),
    tags$div(
      class = "d-flex flex-column gap-4",
      blocks
    )
  )
}
