server <- function(input, output, session) {
  session_id <- paste0("shiny-", as.integer(Sys.time()), "-", sample(100000, 1))
  rag <- nd.util::rag_client(
    .base_url = BASE_URL,
    .api_key = RAG_SERVICE_API_KEY,
    .session_id = session_id
  )

  rv <- reactiveValues(
    ingest_job = NULL,
    ingest_status = NULL,
    ingest_done = FALSE,
    answer = "",
    sources = list(),
    history = list(),
    last_question = "",
    docs = list()
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
    tab <- input$ingest_tab %||% "HTML-URL"
    if (tab == "PDF") {
      req(input$pdfs)
      pdf_paths <- input$pdfs$datapath
      label <- input$doc_label %||% NULL
      tryCatch(
        {
          job_id <- rag$ingest_pdf_async(pdf_paths, .label = label, .filenames = input$pdfs$name)
          rv$ingest_job <- job_id
          rv$ingest_done <- FALSE
          rv$ingest_status <- list(status = "running", progress = 0, message = "Starte PDF-Ingest")
        },
        error = function(e) {
          showNotification(
            paste("Ingest start failed:", e$message),
            type = "error"
          )
        }
      )
    } else {
      url <- trimws(input$urls %||% "")
      if (!nzchar(url)) {
        showNotification("Enter a URL.", type = "warning")
        return()
      }
      label <- input$doc_label %||% NULL
      tryCatch(
        {
          job_id <- rag$ingest_url_async(url, .label = label)
          rv$ingest_job <- job_id
          rv$ingest_done <- FALSE
          rv$ingest_status <- list(status = "running", progress = 0, message = "Starte URL-Ingest")
        },
        error = function(e) {
          showNotification(
            paste("Ingest URLs failed:", e$message),
            type = "error"
          )
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
            showNotification(
              paste("Ingest failed:", status$error %||% status$message),
              type = "error"
            )
          } else {
            showNotification("Ingest completed", type = "message")
            tryCatch(
              {
                rv$docs <- rag$list_documents()
              },
              error = function(e) {
                showNotification(paste("Dokumente laden fehlgeschlagen:", e$message), type = "warning")
              }
            )
          }
        }
      },
      error = function(e) {
        rv$ingest_done <- TRUE
        showNotification(
          paste("Ingest status failed:", e$message),
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
    question <- input$question
    if (!nzchar(question)) {
      showNotification("Enter a question.", type = "warning")
      return()
    }
    rv$answer <- ""
    rv$sources <- list()
    rv$last_question <- question
    current_history <- rv$history
    session$sendCustomMessage("chat-reset", list())

    # Trigger client-side streaming fetch
    session$sendCustomMessage(
      "chat-start",
      rag$chat_stream_config(
        .message = question,
        .history = current_history
      )
    )
  })

  observeEvent(input$chat_result, {
    res <- input$chat_result
    if (is.null(res)) {
      return()
    }
    rv$answer <- res$answer %||% ""
    rv$sources <- nd.util::rag_source_list(res$sources)
    if (!is.null(rv$sources) && length(rv$sources) > 0) {
      cat("\n--- Verwendete Snippets ---\n")
      for (s in rv$sources) {
        if (!is.null(s$context_text)) {
          cat(sprintf("[%s] %s\n", s$i %||% "?", s$context_text))
        }
      }
      cat("--------------------------\n")
    }
    rv$history <- append(
      rv$history,
      list(
        list(role = "user", content = rv$last_question),
        list(role = "assistant", content = rv$answer)
      )
    )
    if (!is.null(res$prompts)) {
      cat("\n--- Verwendete Prompts ---\n")
      for (nm in names(res$prompts)) {
        cat(nm, ":\n", res$prompts[[nm]] %||% "NULL", "\n\n")
      }
      cat("-------------------------\n")
    }
  })

  observeEvent(input$chat_error, {
    err <- input$chat_error
    if (!is.null(err$error)) {
      showNotification(paste("Chat failed:", err$error), type = "error")
    }
    isolate({
      rv$answer <- ""
      rv$sources <- list()
    })
  })

  observeEvent(input$refresh_docs, {
    tryCatch(
      {
        rv$docs <- rag$list_documents()
      },
      error = function(e) {
        showNotification(paste("Dokumente laden fehlgeschlagen:", e$message), type = "error")
      }
    )
  })

  output$sources <- renderUI({
    if (is.null(rv$sources) || length(rv$sources) == 0) {
      return(div("No sources returned."))
    }
    tagList(lapply(rv$sources, function(s) {
      pages <- if (!is.null(s$page_numbers)) {
        paste("p.", paste(s$page_numbers, collapse = ", "))
      } else {
        "p. ?"
      }
      heading <- if (!is.null(s$headings) && length(s$headings) > 0) {
        paste(" — ", tail(s$headings, 1))
      } else {
        ""
      }
      div(
        paste0("[", s$i %||% NA_integer_, "] "),
        s$source_file %||% "unknown",
        " (",
        pages,
        ")",
        heading
      )
    }))
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
        showNotification(paste("Gelöscht:", lbl), type = "message")
      },
      error = function(e) {
        showNotification(paste("Löschen fehlgeschlagen:", e$message), type = "error")
      }
    )
  })
}
