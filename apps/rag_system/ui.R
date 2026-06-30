tags <- htmltools::tags

ui <- nd.util::nd_app(
  .title = "RAG-System",
  .head = tagList(
    shiny::includeCSS("www/style.css"),
    tags$style(htmltools::HTML(CHAT_CSS)),
    # Re-init-fähige Popover-Engine (für dynamisch gerenderte Chat-Inhalte)
    # und Chat-Streaming.
    shiny::includeScript("www/popover.js"),
    shiny::includeScript("www/chatUi.js")
  ),
  tags$div(
    class = "d-flex flex-column gap-4",
    bslib::card(
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
          uiOutput("ingest_progress")
        )
      ),
      bslib::card(
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
      ),
      bslib::card(
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
    )
  )
