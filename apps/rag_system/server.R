server <- function(input, output, session) {
  # Bei kurzem Verbindungsabbruch (z. B. Proxy schließt idle WebSocket) still
  # zur selben, weiterlaufenden Session reconnecten statt "Disconnected"-Overlay.
  session$allowReconnect(TRUE)

  # session_id kann über die URL-Query übergeben werden, damit mehrere separat
  # eingebettete Bausteine (ingest/documents/chat) dieselbe RAG-Session teilen.
  # Fehlt der Parameter, wird – wie bisher – eine eigene Session erzeugt.
  query <- shiny::parseQueryString(isolate(session$clientData$url_search))
  session_id <- query$session_id %||% ""
  if (!nzchar(trimws(session_id))) {
    session_id <- paste0("shiny-", as.integer(Sys.time()), "-", sample(100000, 1))
  }
  ui_element <- tolower(trimws(query$ui_element %||% ""))
  rag <- nd.util::rag_client(
    .base_url = BASE_URL,
    .api_key = RAG_SERVICE_API_KEY,
    .session_id = session_id
  )

  # Zentrale Meldungsausgabe: zeigt die Nachricht als Shiny-Notification an UND
  # schreibt sie zusätzlich auf die Konsole (Server-Log) zur Diagnose.
  notify <- function(msg, type = c("error", "warning", "message")) {
    type <- match.arg(type)
    prefix <- switch(type, error = "[ERROR]", warning = "[WARN]", message = "[INFO]")
    message(sprintf("%s [%s] %s", prefix, session_id, msg))
    showNotification(msg, type = type)
  }

  rv <- reactiveValues(
    ingest_job = NULL,
    ingest_status = NULL,
    ingest_done = FALSE,
    history = list(),
    last_question = "",
    docs = list(),
    # Chat-Verlauf: abgeschlossene Runden + aktuell streamende Runde.
    dialogue = list(),
    cur_question = "",
    cur_answer = "",
    cur_sources = list(),
    streaming = FALSE,
    # Zähler, der bei jedem abgeschlossenen Ingest erhöht wird; treibt die
    # Baustein-übergreifende Aktualisierung der Dokumentenliste an.
    ingest_version = 0
  )

  # initial document load
  observeEvent(TRUE, {
    tryCatch(
      {
        rv$docs <- rag$list_documents()
      },
      error = function(e) {
        rv$docs <- list()
      }
    )
  }, once = TRUE)

  # Wird der Dokumente-Baustein eigenständig eingebettet (eigene Session), so
  # bekommt er Ingests aus anderen iframes derselben RAG-Session nicht direkt
  # mit. Die Bausteine teilen sich jedoch Origin und session_id und melden
  # abgeschlossene Ingests clientseitig per BroadcastChannel (siehe docsync.js);
  # der Dokumente-Baustein löst daraufhin `external_refresh` aus und lädt die
  # Liste neu.
  observeEvent(input$external_refresh, {
    tryCatch(
      {
        rv$docs <- rag$list_documents()
      },
      error = function(e) {
        notify(paste("Dokumente laden fehlgeschlagen:", e$message), type = "warning")
      }
    )
  })

  # Verstecktes Output, dessen Wert-Update (Zähler) der Client per
  # BroadcastChannel an die anderen Bausteine weiterreicht. suspendWhenHidden
  # muss FALSE sein, damit auch das unsichtbare Output an den Browser gepusht wird.
  output$ingest_version <- renderText(as.character(rv$ingest_version))
  outputOptions(output, "ingest_version", suspendWhenHidden = FALSE)

  # Der Ingest-Button (bslib::input_task_button, auto_reset = FALSE) bleibt im
  # Busy-Zustand, bis der asynchrone Ingest abgeschlossen oder fehlgeschlagen
  # ist; hier wird er wieder freigegeben.
  reset_ingest_btn <- function() {
    bslib::update_task_button("ingest_btn", state = "ready", session = session)
  }
  reset_send_btn <- function() {
    bslib::update_task_button("send_btn", state = "ready", session = session)
  }

  observeEvent(input$ingest_btn, {
    mode <- if (identical(input$ingest_mode, "PDF")) "pdf" else "url"
    document_name <- trimws(input$doc_name %||% "")

    if (mode == "pdf") {
      has_pdf <- !is.null(input$pdfs) && length(input$pdfs$datapath) > 0
      if (!has_pdf) {
        notify("Bitte eine PDF auswählen.", type = "warning")
        reset_ingest_btn()
        return()
      }
      pdf_paths <- input$pdfs$datapath
      document_name <- if (nzchar(document_name)) document_name else input$pdfs$name
      tryCatch(
        {
          job_id <- rag$ingest_pdf_async(
            pdf_paths,
            .name = document_name
          )
          rv$ingest_job <- job_id
          rv$ingest_done <- FALSE
          rv$ingest_status <- list(status = "running", progress = 0, message = "Starte PDF-Ingest")
        },
        error = function(e) {
          notify(paste("Ingest-Start fehlgeschlagen:", e$message), type = "error")
          reset_ingest_btn()
        }
      )
    } else {
      url <- trimws(input$urls %||% "")
      if (!nzchar(url)) {
        notify("Bitte eine URL eingeben.", type = "warning")
        reset_ingest_btn()
        return()
      }
      document_name <- if (nzchar(document_name)) document_name else NULL
      tryCatch(
        {
          job_id <- rag$ingest_url_async(
            url,
            .name = document_name
          )
          rv$ingest_job <- job_id
          rv$ingest_done <- FALSE
          rv$ingest_status <- list(status = "running", progress = 0, message = "Starte URL-Ingest")
        },
        error = function(e) {
          notify(paste("URL-Ingest fehlgeschlagen:", e$message), type = "error")
          reset_ingest_btn()
        }
      )
    }
  })

  observe({
    if (is.null(rv$ingest_job) || isTRUE(rv$ingest_done)) {
      return()
    }
    invalidateLater(1000)
    tryCatch(
      {
        status <- rag$poll_ingest(rv$ingest_job)
        rv$ingest_status <- status
        if (status$status %in% c("succeeded", "failed")) {
          rv$ingest_done <- TRUE
          reset_ingest_btn()
          if (status$status == "failed") {
            notify(
              paste("Ingest fehlgeschlagen:", status$error %||% status$message),
              type = "error"
            )
          } else {
            notify("Ingest abgeschlossen", type = "message")
            # Eingabefelder für den nächsten Ingest leeren; das fileInput hat
            # kein update-Pendant und wird clientseitig zurückgesetzt (ingestUi.js).
            updateTextInput(session, "urls", value = "")
            updateTextInput(session, "doc_name", value = "")
            session$sendCustomMessage("rag-reset-file-input", "pdfs")
            tryCatch(
              {
                rv$docs <- rag$list_documents()
              },
              error = function(e) {
                notify(paste("Dokumente laden fehlgeschlagen:", e$message), type = "warning")
              }
            )
            # Signal für separat eingebettete Bausteine: Zähler erhöhen. Der
            # Client überträgt dieses Output-Update per BroadcastChannel (siehe
            # docsync.js). Reaktive Outputs werden – anders als Custom Messages
            # aus Timer-Observern – zuverlässig auch ohne Client-Interaktion an
            # den Browser gepusht.
            rv$ingest_version <- rv$ingest_version + 1
          }
        }
      },
      error = function(e) {
        rv$ingest_done <- TRUE
        reset_ingest_btn()
        notify(
          paste("Ingest-Status fehlgeschlagen:", e$message),
          type = "error"
        )
      }
    )
  })

  output$ingest_progress <- renderUI({
    st <- rv$ingest_status
    if (is.null(st) || is.null(st$progress)) {
      return(NULL)
    }
    pct <- max(0, min(100, st$progress))
    running <- identical(st$status, "running")
    div(
      class = "progress",
      role = "progressbar",
      `aria-valuenow` = pct,
      `aria-valuemin` = "0",
      `aria-valuemax` = "100",
      div(
        class = paste(
          "progress-bar",
          if (running) "progress-bar-striped progress-bar-animated"
        ),
        style = paste0("width: ", pct, "%;"),
        paste0(pct, "%")
      )
    )
  })

  observeEvent(input$send_btn, {
    question <- trimws(input$question %||% "")
    if (!nzchar(question)) {
      notify("Bitte eine Frage eingeben.", type = "warning")
      reset_send_btn()
      return()
    }
    rv$cur_question <- question
    rv$cur_answer <- ""
    rv$cur_sources <- list()
    rv$streaming <- TRUE
    rv$last_question <- question
    current_history <- rv$history

    # Streaming clientseitig anstoßen; Tokens kommen über chat_progress zurück.
    session$sendCustomMessage(
      "chat-start",
      rag$chat_stream_config(
        .message = question,
        .history = current_history
      )
    )
    updateTextInput(session, "question", value = "")
  })

  # Zwischenstand: vollständige Absätze, die der Client weiterreicht.
  observeEvent(input$chat_progress, {
    prog <- input$chat_progress
    rv$cur_answer <- prog$answer %||% ""
    rv$cur_sources <- nd.util::rag_source_list(prog$sources)
  })

  observeEvent(input$chat_result, {
    res <- input$chat_result
    if (is.null(res)) {
      return()
    }
    answer <- res$answer %||% rv$cur_answer %||% ""
    sources <- nd.util::rag_source_list(res$sources)

    # Abgeschlossene Runde in den sichtbaren Verlauf übernehmen.
    rv$dialogue <- append(
      rv$dialogue,
      list(list(
        question = rv$cur_question,
        answer = answer,
        sources = sources
      ))
    )
    rv$history <- append(
      rv$history,
      list(
        list(role = "user", content = rv$last_question),
        list(role = "assistant", content = answer)
      )
    )

    # Sichtbaren Verlauf und gesendete Historie begrenzen.
    max_dialogue <- 10
    if (length(rv$dialogue) > max_dialogue) {
      rv$dialogue <- rv$dialogue[(length(rv$dialogue) - max_dialogue + 1):length(rv$dialogue)]
    }
    max_turns <- 20
    if (length(rv$history) > max_turns) {
      rv$history <- rv$history[(length(rv$history) - max_turns + 1):length(rv$history)]
    }

    rv$streaming <- FALSE
    rv$cur_question <- ""
    rv$cur_answer <- ""
    rv$cur_sources <- list()
    reset_send_btn()
  })

  observeEvent(input$chat_error, {
    err <- input$chat_error
    if (!is.null(err$error)) {
      notify(paste("Chat fehlgeschlagen:", err$error), type = "error")
    }
    rv$streaming <- FALSE
    rv$cur_question <- ""
    rv$cur_answer <- ""
    rv$cur_sources <- list()
    reset_send_btn()
  })

  # Gesamten Dialog serverseitig rendern (Fallstudien-Stil).
  output$chat_dialogue <- renderUI({
    turns <- lapply(rv$dialogue, function(turn) {
      tagList(
        rag_make_question_box(turn$question),
        rag_make_answer_box(turn$answer, turn$sources)
      )
    })

    if (isTRUE(rv$streaming)) {
      streaming_turn <- tagList(
        rag_make_question_box(rv$cur_question),
        if (nzchar(rv$cur_answer %||% "")) {
          rag_make_answer_box(rv$cur_answer, rv$cur_sources)
        } else {
          rag_make_answer_box(NULL, list(), .loading = TRUE)
        }
      )
      turns <- c(turns, list(streaming_turn))
    }

    if (length(turns) == 0) {
      return(div(
        class = "text-muted",
        "Noch keine Nachrichten. Stellen Sie eine Frage."
      ))
    }
    tagList(turns)
  })

  output$doc_list <- renderUI({
    if (is.null(rv$docs) || length(rv$docs) == 0) {
      return(div(class = "card-body text-muted", "Keine Dokumente gefunden."))
    }
    tags$ul(
      class = "list-group list-group-flush",
      lapply(rv$docs, function(d) {
        lbl <- d$label %||% "Unbenannt"
        btn_js <- sprintf(
          "Shiny.setInputValue('delete_doc', %s, {priority: 'event'});",
          jsonlite::toJSON(lbl, auto_unbox = TRUE)
        )
        tags$li(
          class = paste(
            "list-group-item d-flex justify-content-between",
            "align-items-center gap-2"
          ),
          div(
            strong(lbl),
            span(paste0(" (", d$count %||% 0, " Einträge)"))
          ),
          tags$button(
            type = "button",
            class = "btn btn-outline-danger btn-sm text-nowrap",
            onclick = btn_js,
            tags$i(class = "fa-solid fa-trash-can", role = "presentation"),
            "Löschen"
          )
        )
      })
    )
  })

  observeEvent(input$delete_doc, {
    lbl <- input$delete_doc %||% ""
    if (!nzchar(lbl)) return()
    tryCatch(
      {
        rag$delete_documents(lbl)
        rv$docs <- rag$list_documents()
        notify(paste("Gelöscht:", lbl), type = "message")
      },
      error = function(e) {
        notify(paste("Löschen fehlgeschlagen:", e$message), type = "error")
      }
    )
  })
}
