tags <- htmltools::tags

ui <- nd.util::nd_page(
  .page_type = "app",
  .navbar = NULL,
  .main = list(
    tags$head(
      shiny::includeScript("www/chatUi.js"),
      # markdown renderer for chat content
      tags$script(src = "https://cdn.jsdelivr.net/npm/marked/marked.min.js"),
      tags$link(
        rel = "stylesheet",
        href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css"
      ),
      shiny::includeCSS("www/style.css")
    ),
    fluidRow(
      column(
        width = 4,
        wellPanel(
          h4("Ingest"),
          bslib::navset_card_tab(
            id = "ingest_tab",
            selected = "HTML-URL",
            bslib::nav_panel(
              "HTML-URL",
              textInput(
                "urls",
                "Eine HTML-URL einfügen",
                value = "",
                placeholder = "https://example.com/page"
              )
            ),
            bslib::nav_panel(
              "PDF",
              fileInput(
                "pdfs",
                "PDF auswählen",
                multiple = FALSE,
                accept = ".pdf"
              )
            )
          ),
          textInput(
            "doc_label",
            "Beschriftung für das Dokument (optional)",
            ""
          ),
          actionButton("ingest_btn", "Ingest starten", class = "btn-primary"),
          tags$hr(),
          uiOutput("ingest_status"),
          uiOutput("ingest_progress")
        )
      ),
      column(
        width = 4,
        wellPanel(
          h4("Dokumente"),
          actionButton(
            "refresh_docs",
            "Aktualisieren",
            class = "btn-secondary btn-sm"
          ),
          tags$hr(),
          uiOutput("doc_list")
        )
      ),
      column(
        width = 4,
        wellPanel(
          h4("Chat"),
          strong("Antwort:"),
          div(
            id = "chat_stream",
            class = "chat-stream",
            style = "min-height: 360px;"
          ),
          tags$hr(),
          textInput("question", "Frage", ""),
          actionButton("send_btn", "Senden", class = "btn-success")
        )
      )
    )
  )
)

# ui <- bslib::page_fluid(
#   tags$head(
#     shiny::includeScript("www/chatUi.js"),
#     # markdown renderer for chat content
#     tags$script(src = "https://cdn.jsdelivr.net/npm/marked/marked.min.js"),
#     tags$link(
#       rel = "stylesheet",
#       href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css"
#     ),
#     shiny::includeCSS("www/style.css")
#   ),
#   fluidRow(
#     column(
#       width = 4,
#       wellPanel(
#         h4("Ingest"),
#         bslib::navset_card_tab(
#           id = "ingest_tab",
#           selected = "HTML-URL",
#           bslib::nav_panel(
#             "HTML-URL",
#             textInput(
#               "urls",
#               "Eine HTML-URL einfügen",
#               value = "",
#               placeholder = "https://example.com/page"
#             )
#           ),
#           bslib::nav_panel(
#             "PDF",
#             fileInput(
#               "pdfs",
#               "PDF auswählen",
#               multiple = FALSE,
#               accept = ".pdf"
#             )
#           )
#         ),
#         textInput("doc_label", "Beschriftung für das Dokument (optional)", ""),
#         actionButton("ingest_btn", "Ingest starten", class = "btn-primary"),
#         tags$hr(),
#         uiOutput("ingest_status"),
#         uiOutput("ingest_progress")
#       )
#     ),
#     column(
#       width = 4,
#       wellPanel(
#         h4("Dokumente"),
#         actionButton(
#           "refresh_docs",
#           "Aktualisieren",
#           class = "btn-secondary btn-sm"
#         ),
#         tags$hr(),
#         uiOutput("doc_list")
#       )
#     ),
#     column(
#       width = 4,
#       wellPanel(
#         h4("Chat"),
#         strong("Antwort:"),
#         div(
#           id = "chat_stream",
#           class = "chat-stream",
#           style = "min-height: 360px;"
#         ),
#         tags$hr(),
#         textInput("question", "Frage", ""),
#         actionButton("send_btn", "Senden", class = "btn-success")
#       )
#     )
#   )
# )
