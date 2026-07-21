library(shiny)
library(htmltools)
library(stringi)

shiny::addResourcePath(
  prefix = "assets",
  directoryPath = here::here("node_modules", "@endikau", "nd_assets", "dist")
)

data <- qs2::qs_read(here::here(
  "apps",
  "protocols",
  "data",
  "protokolle_output",
  "protokolle_summary.qs2"
))


render_teilnehmende <- function(.teilnehmende_tbl) {
  if (is.null(.teilnehmende_tbl) || nrow(.teilnehmende_tbl) == 0) {
    return(NULL)
  }

  tags$div(
    class = "summary-chips",
    purrr::map(seq_len(nrow(.teilnehmende_tbl)), function(.i) {
      .name <- .teilnehmende_tbl$name[.i]
      .rolle <- .teilnehmende_tbl$rolle[.i]
      tags$span(
        class = "chip",
        if (!is.na(.rolle) && nzchar(.rolle)) {
          stri_c(.name, " (", .rolle, ")")
        } else {
          .name
        }
      )
    })
  )
}

render_bullet_list <- function(.items) {
  if (is.null(.items) || length(.items) == 0) {
    return(tags$em("Keine Einträge."))
  }
  tags$ul(
    class = "summary-list",
    purrr::map(.items, ~ tags$li(.x))
  )
}

render_aufgaben_table <- function(.aufgaben_tbl) {
  if (is.null(.aufgaben_tbl) || nrow(.aufgaben_tbl) == 0) {
    return(tags$em("Keine Aufgaben."))
  }
  tags$table(
    class = "summary-table",
    tags$thead(
      tags$tr(
        tags$th("Wer"),
        tags$th("Was"),
        tags$th("Bis wann")
      )
    ),
    tags$tbody(
      purrr::map(seq_len(nrow(.aufgaben_tbl)), function(.i) {
        tags$tr(
          tags$td(.aufgaben_tbl$verantwortlich[.i]),
          tags$td(.aufgaben_tbl$aufgabe[.i]),
          tags$td(.aufgaben_tbl$frist[.i])
        )
      })
    )
  )
}

##################################
########### UI ###################
##################################

ui <- nd.util::nd_page(
  .page_type = "app",
  .navbar = NULL,
  .main = list(
    tags$style(HTML(
      "
      .protokoll-card { border: 1px solid #eee; border-radius: 12px; padding: 16px; }
      .protokoll-title { margin: 0 0 4px 0; font-size: 1.2rem; line-height: 1.25; }
      .protokoll-meta { font-size: 0.9rem; margin-bottom: 12px; }
      .protokoll-text {
        font-family: var(--bs-font-monospace);
        font-size: 0.875rem;
        background-color: #eee;
        padding: 12px;
        border-radius: 6px;
        max-height: 400px;
        overflow-y: auto;
        white-space: pre-wrap;
      }

      .summary-card { border: 1px solid #eee; border-radius: 12px; padding: 16px; margin-top: 1rem; }
      .summary-section { margin-bottom: 1.25rem; }
      .summary-section:last-child { margin-bottom: 0; }
      .summary-section h4 {
        font-size: 1rem;
        font-weight: 600;
        margin: 0 0 0.5rem 0;
        color: #2e2933;
      }
      .summary-kurzfassung {
        font-style: italic;
        margin-bottom: 1rem;
        padding: 0.75rem;
        background-color: #F2F1F4;
        border-left: 3px solid #837591;
        border-radius: 4px;
      }
      .summary-chips { display: flex; flex-wrap: wrap; gap: 0.4rem; }
      .chip {
        background-color: #837591;
        color: #fefffc;
        padding: 3px 10px;
        border-radius: 12px;
        font-size: 0.875rem;
      }
      .summary-list { padding-left: 1.25rem; margin: 0; }
      .summary-list li { margin-bottom: 0.3rem; }
      .summary-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 0.9rem;
      }
      .summary-table th, .summary-table td {
        text-align: left;
        padding: 6px 10px;
        border-bottom: 1px solid #eee;
        vertical-align: top;
      }
      .summary-table th { background-color: #eee; font-weight: 600; }
    "
    )),

    tags$div(
      class = "d-grid mb-4",
      nd.util::nd_button_block(
        .id = "random_protokoll",
        .label = "Zufälliges Protokoll wählen",
        .fa_class = "fa-solid fa-dice",
        .fa_class_busy = "fa-solid fa-dice fa-spin"
      )
    ),

    uiOutput("protokoll_output"),

    uiOutput("generate_button_output"),

    uiOutput("summary_output"),

    htmltools::suppressDependencies("font-awesome")
  )
)

#####################################
######### Server ####################
#####################################

server <- function(input, output, session) {
  current_protokoll <- reactiveVal(NULL)
  show_summary <- reactiveVal(FALSE)

  observeEvent(input$random_protokoll, {
    .row <- data[sample(nrow(data), 1), ]
    current_protokoll(.row)
    show_summary(FALSE)
  })

  observeEvent(input$generate_summary, {
    show_summary(TRUE)
  })

  output$protokoll_output <- renderUI({
    .row <- current_protokoll()
    if (is.null(.row)) {
      return(NULL)
    }

    tags$div(
      class = "protokoll-card",
      tags$h3(class = "protokoll-title", .row$titel),
      tags$div(
        class = "protokoll-meta",
        .row$branche
      ),
      tags$div(class = "protokoll-text", .row$protokoll_volltext)
    )
  })

  output$generate_button_output <- renderUI({
    if (is.null(current_protokoll())) {
      return(NULL)
    }
    if (show_summary()) {
      return(NULL)
    }

    tags$div(
      class = "d-grid mt-4",
      nd.util::nd_button_block(
        .id = "generate_summary",
        .label = "Zusammenfassung generieren",
        .fa_class = "fa-solid fa-wand-magic-sparkles",
        .fa_class_busy = "fa-solid fa-sync fa-spin"
      )
    )
  })

  output$summary_output <- renderUI({
    if (!show_summary()) {
      return(NULL)
    }
    .row <- current_protokoll()
    if (is.null(.row)) {
      return(NULL)
    }

    .teilnehmende <- .row$teilnehmende[[1]]
    .beschluesse <- .row$beschluesse[[1]]
    .aufgaben <- .row$aufgaben[[1]]
    .offene_punkte <- .row$offene_punkte[[1]]

    tags$div(
      class = "summary-card",

      tags$div(
        class = "summary-kurzfassung",
        .row$kurzfassung
      ),

      tags$div(
        class = "summary-section",
        tags$h4("Teilnehmende"),
        render_teilnehmende(.teilnehmende)
      ),

      tags$div(
        class = "summary-section",
        tags$h4("Beschlüsse"),
        render_bullet_list(.beschluesse)
      ),

      tags$div(
        class = "summary-section",
        tags$h4("Aufgaben"),
        render_aufgaben_table(.aufgaben)
      ),

      tags$div(
        class = "summary-section",
        tags$h4("Offene Punkte"),
        render_bullet_list(.offene_punkte)
      )
    )
  })
}

shinyApp(ui, server)
