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
    streaming = FALSE
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

  observeEvent(input$ingest_btn, {
    mode <- if (identical(input$ingest_mode, "PDF")) "pdf" else "url"
    document_name <- trimws(input$doc_name %||% "")

    if (mode == "pdf") {
      has_pdf <- !is.null(input$pdfs) && length(input$pdfs$datapath) > 0
      if (!has_pdf) {
        notify("Bitte eine PDF auswählen.", type = "warning")
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
        }
      )
    } else {
      url <- trimws(input$urls %||% "")
      if (!nzchar(url)) {
        notify("Bitte eine URL eingeben.", type = "warning")
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
          if (status$status == "failed") {
            notify(
              paste("Ingest fehlgeschlagen:", status$error %||% status$message),
              type = "error"
            )
          } else {
            notify("Ingest abgeschlossen", type = "message")
            tryCatch(
              {
                rv$docs <- rag$list_documents()
              },
              error = function(e) {
                notify(paste("Dokumente laden fehlgeschlagen:", e$message), type = "warning")
              }
            )
          }
        }
      },
      error = function(e) {
        rv$ingest_done <- TRUE
        notify(
          paste("Ingest-Status fehlgeschlagen:", e$message),
          type = "error"
        )
      }
    )
  })

  output$ingest_status <- renderUI({
    st <- rv$ingest_status
    if (is.null(st)) {
      return(NULL)
    }
    status_text <- paste0("Status: ", st$status)
    msg <- st$message %||% ""
    tagList(
      div(status_text),
      if (nzchar(msg)) div(msg) else NULL
    )
  })

  output$ingest_progress <- renderUI({
    st <- rv$ingest_status
    if (is.null(st) || is.null(st$progress)) {
      return(NULL)
    }
    pct <- max(0, min(100, st$progress))
    div(
      style = "background:#eee; height:20px; width:100%; border-radius:4px;",
      div(
        style = paste0(
          "height:100%; width:",
          pct,
          "%; background:#007bff; color:white; text-align:center; border-radius:4px;"
        ),
        paste0(pct, "%")
      )
    )
  })

  observeEvent(input$send_btn, {
    question <- trimws(input$question %||% "")
    if (!nzchar(question)) {
      notify("Bitte eine Frage eingeben.", type = "warning")
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

  observeEvent(input$refresh_docs, {
    tryCatch(
      {
        rv$docs <- rag$list_documents()
      },
      error = function(e) {
        notify(paste("Dokumente laden fehlgeschlagen:", e$message), type = "error")
      }
    )
  })

  output$doc_list <- renderUI({
    if (is.null(rv$docs) || length(rv$docs) == 0) {
      return(div("Keine Dokumente gefunden."))
    }
    tagList(lapply(rv$docs, function(d) {
      lbl <- d$label %||% "Unbenannt"
      btn_js <- sprintf(
        "Shiny.setInputValue('delete_doc', %s, {priority: 'event'});",
        jsonlite::toJSON(lbl, auto_unbox = TRUE)
      )
      div(
        class = "doc-item d-flex justify-content-between align-items-center mb-2",
        div(
          strong(lbl),
          span(paste0(" (", d$count %||% 0, " Einträge)"))
        ),
        tags$button(
          type = "button",
          class = "btn btn-danger btn-sm",
          onclick = btn_js,
          "Löschen"
        )
      )
    }))
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
