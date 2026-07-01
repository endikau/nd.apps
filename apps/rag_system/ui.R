tags <- htmltools::tags

# Die drei Bausteine als eigenständige Cards, damit sie einzeln oder gemeinsam
# ausgeliefert werden können (Auswahl über den Query-Parameter `ui_element`).
ingest_card <- bslib::card(
  fill = FALSE,
  bslib::card_header("Ingest"),
  bslib::card_body(
    fillable = FALSE,
    div(
      class = "ingest-tabs",
      radioButtons(
        "ingest_mode",
        label = NULL,
        choices = c("HTML-URL", "PDF"),
        selected = "HTML-URL",
        inline = TRUE
      )
    ),
    conditionalPanel(
      condition = "input.ingest_mode == 'HTML-URL'",
      textInput(
        "urls",
        "Eine HTML-URL einfügen",
        value = "",
        placeholder = "https://example.com/page"
      )
    ),
    conditionalPanel(
      condition = "input.ingest_mode == 'PDF'",
      fileInput(
        "pdfs",
        "PDF auswählen",
        multiple = FALSE,
        accept = ".pdf"
      )
    ),
    textInput(
      "doc_name",
      "Dokumentname (optional)",
      ""
    ),
    actionButton("ingest_btn", "Ingest starten", class = "btn-primary"),
    tags$hr(),
    uiOutput("ingest_status"),
    uiOutput("ingest_progress"),
    # Verstecktes Signal-Output für die Baustein-übergreifende Synchronisation.
    tags$div(style = "display: none;", textOutput("ingest_version"))
  )
)

documents_card <- bslib::card(
  fill = FALSE,
  bslib::card_header("Dokumente"),
  bslib::card_body(
    fillable = FALSE,
    actionButton(
      "refresh_docs",
      "Aktualisieren",
      class = "btn-secondary btn-sm"
    ),
    tags$hr(),
    uiOutput("doc_list")
  )
)

chat_card <- bslib::card(
  fill = FALSE,
  bslib::card_header("Chat"),
  bslib::card_body(
    fillable = FALSE,
    div(
      class = "rag-chat",
      uiOutput("chat_dialogue")
    ),
    tags$hr(),
    textInput("question", "Frage", ""),
    actionButton("send_btn", "Senden", class = "btn-success")
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
      shiny::includeScript("www/docsync.js")
    ),
    tags$div(
      class = "d-flex flex-column gap-4",
      blocks
    )
  )
}
