library(shiny)
library(bslib)

shiny::addResourcePath(
  prefix = "assets",
  directoryPath = here::here("node_modules", "@endikau", "nd_assets", "dist")
)

DEFAULT_RAG_SERVICE_URL <- if (file.exists("/.dockerenv")) {
  "http://nd_services-rag_service:9126"
} else {
  "https://rag_service.dsjlu.wirtschaft.uni-giessen.de"
}

BASE_URL <- Sys.getenv(
  "RAG_SERVICE_URL",
  unset = DEFAULT_RAG_SERVICE_URL
)
RAG_SERVICE_API_KEY <- Sys.getenv("RAG_SERVICE_API_KEY", unset = "")

# Upload-Limit für den PDF-Ingest; größere Requests lehnt Shiny mit einem
# Upload-Fehler im fileInput ab.
MAX_UPLOAD_MB <- 20
options(shiny.maxRequestSize = MAX_UPLOAD_MB * 1024^2)

`%||%` <- rlang::`%||%`

tags <- htmltools::tags

# Chat-Styles einmal aus chat.scss kompilieren (übernommen aus der Fallstudie).
CHAT_CSS <- sass::sass(sass::sass_file(here::here("apps", "rag_system", "chat.scss")))

# --- Chat-Rendering-Helfer, übernommen aus -----------------------------------
# nd.site/content/case_studies/rag_system/index.qmd. Statt eines fertigen
# response-Objekts nehmen sie Antworttext + Quellenliste entgegen und sind
# robust gegen (noch) fehlende Quellen während des Streamings.

# Antworttext (Markdown) zu HTML rendern, Zitiermarken [1], [2] durch
# Info-Popover-Anker ersetzen und breite Tabellen scrollbar machen.
rag_format_response <- function(.answer, .sources = list()) {
  .answer <- .answer %||% ""
  .sources <- .sources %||% list()

  .make_source_anchor <- function(.id) {
    stringi::stri_c(
      "<a tabindex=\"0\" role=\"button\" data-bs-toggle=\"popover\" ",
      "data-bs-template-id=\"",
      htmltools::htmlEscape(.id),
      "\"><span class=\"text-primary\"><i class=\"fa-solid fa-circle-info\" ",
      "role=\"presentation\"></i></span></a>"
    )
  }

  # Quellen nach ihrer Zitiernummer (i) indexieren.
  .source_dict <- list()
  for (.source in .sources) {
    .i <- .source$i %||% NA
    .i <- if (length(.i)) as.character(.i[[1]]) else NA_character_
    if (is.na(.i) || !nzchar(.i)) next
    .id <- digest::digest(
      list(.source, Sys.time(), stats::runif(1)),
      algo = "crc32c"
    )
    .pages <- unlist(.source$page_numbers %||% list(), use.names = FALSE)
    .pages_txt <- if (length(.pages)) {
      stringi::stri_c(.pages, collapse = ", ")
    } else {
      "—"
    }
    .snippet <- .source$context_text %||% .source$snippet %||% ""
    .source_dict[[.i]] <- list(
      anchor = .make_source_anchor(.id),
      template = tags$template(
        id = .id,
        tags$ul(
          class = "list-group list-group-flush",
          tags$li(
            tags$code("Dokument:"),
            .source$source_file %||% "Unbekannt",
            class = "list-group-item"
          ),
          tags$li(
            tags$code("Seitenzahl:"),
            .pages_txt,
            class = "list-group-item"
          ),
          tags$li(tags$code("Auszug:"), .snippet, class = "list-group-item")
        )
      )
    )
  }

  # Antwort nach Markdown rendern und Tabellen in Scroll-Container wickeln.
  .response_html <- .answer |>
    commonmark::markdown_html(extensions = TRUE) |>
    stringi::stri_replace_all_regex(
      pattern = "(?s)<table>.*?</table>",
      replacement = "<div class=\"rag-dialogue-table-scroll\">$0</div>"
    )

  # Zitier-Token wie [1] oder [1, 2] durch die Anker ersetzen; fehlt eine
  # Quelle (z. B. noch nicht gestreamt), bleibt die Ziffer als Text stehen.
  .tokens <- .answer |>
    stringi::stri_extract_all_regex("\\[[[:digit:]]+(, ?[[:digit:]]+)*\\]") |>
    purrr::flatten_chr() |>
    unique()
  .tokens <- .tokens[!is.na(.tokens)]
  for (.token in .tokens) {
    .ids <- unlist(stringi::stri_extract_all_regex(.token, "[[:digit:]]+"))
    .rendered <- vapply(.ids, function(..id) {
      .src <- .source_dict[[..id]]
      # Auflösbare Zitate werden zum Info-Icon-Anker (ohne eckige Klammern);
      # eine (noch) fehlende Quelle bleibt als [n] sichtbar.
      if (is.null(.src)) stringi::stri_c("[", ..id, "]") else .src$anchor
    }, character(1))
    .replacement <- stringi::stri_c(.rendered, collapse = " ")
    .response_html <- stringi::stri_replace_all_fixed(
      .response_html,
      .token,
      .replacement,
      vectorize_all = FALSE
    )
  }

  htmltools::tagList(
    htmltools::HTML(.response_html),
    unname(purrr::map(.source_dict, "template"))
  )
}

# Eine Nutzerfrage als linksbündige Frage-Karte.
rag_make_question_box <- function(.question) {
  tags$div(
    class = "rag-dialogue-row rag-dialogue-row--q",
    tags$div(
      class = paste(
        "rag-dialogue-avatar d-flex align-items-center",
        "justify-content-center bg-primary rounded-start"
      ),
      tags$i(class = "fa-solid fa-user text-white")
    ),
    tags$div(
      class = "rag-dialogue-bubble card rounded-start-0",
      style = "min-width: 0;",
      tags$div(
        class = "card-body rag-dialogue-card-body",
        tags$h5(class = "card-title", "Frage"),
        tags$p(.question)
      )
    )
  )
}

# Eine Assistenten-Antwort als rechtsbündige Antwort-Karte. Bei .loading=TRUE
# wird ein Lade-Indikator statt der (noch leeren) Antwort gezeigt.
rag_make_answer_box <- function(.answer, .sources = list(), .loading = FALSE) {
  .body <- if (isTRUE(.loading)) {
    htmltools::HTML(
      paste0(
        "<span class=\"loading-brain\">",
        "<i class=\"fa-solid fa-brain fa-pulse\"></i></span> Denke nach…"
      )
    )
  } else {
    rag_format_response(.answer, .sources)
  }
  tags$div(
    class = "rag-dialogue-row rag-dialogue-row--a",
    tags$div(
      class = "rag-dialogue-bubble card rounded-end-0",
      style = "min-width: 0;",
      tags$div(
        class = "card-body rag-dialogue-card-body",
        tags$h5(class = "card-title", "Antwort"),
        .body
      )
    ),
    tags$div(
      class = paste(
        "rag-dialogue-avatar d-flex align-items-center",
        "justify-content-center bg-primary rounded-end"
      ),
      tags$i(class = "fa-solid fa-robot text-white")
    )
  )
}
