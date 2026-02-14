# ---- dependencies & config ------------------------------------------------

library(shiny)
library(bslib)
library(httr2)
library(jsonlite)
library(curl)
library(xml2)

shiny::addResourcePath(
  prefix = "assets",
  directoryPath = here::here("node_modules", "@endikau", "nd_assets", "dist")
)

BASE_URL <- Sys.getenv(
  "RAG_SERVICE_URL",
  unset = "https://rag_service.dsjlu.wirtschaft.uni-giessen.de"
)
RAG_SERVICE_API_KEY <- Sys.getenv("RAG_SERVICE_API_KEY", unset = "")

`%||%` <- rlang::`%||%`

SYSTEM_PROMPT <- "Du bist ein Retrieval-Assistant und beantwortest Fragen zu den hochgeladenen Dokumenten der Nutzenden.\n\nRegeln:\n- Nutze nur den bereitgestellten Kontext; erfinde keine Zitate.\n- Für jede Hauptaussage (z. B. Beiträge) füge Zitiermarken wie [1], [2] ein.\n- Jede Zitiermarke muss zu einer der zurückgegebenen Quellen passen."
CONDENSE_PROMPT <- "Gegeben sind der bisherige Chat-Verlauf und eine Nachfrage. Formuliere daraus eine eigenständige Frage.\n\nChat-Verlauf:\n{chat_history}\nNachfrage: {question}\nEigenständige Frage:"
CONTEXT_PROMPT <- "Dies ist ein freundliches Gespräch zwischen Nutzenden und einer KI. Die KI antwortet ausführlich und mit vielen Details aus dem Kontext. Wenn sie etwas nicht weiß, sagt sie das ehrlich.\n\nHier sind die relevanten Dokumente für den Kontext:\n\n{context_str}\n\nAnweisung: Formuliere auf Basis dieser Dokumente eine detaillierte Antwort auf die folgende Frage. Wenn es im Kontext nicht steht, antworte mit „Weiß ich nicht.“"
RESPONSE_PROMPT <- "Du bist ein RAG-Assistent. Antworte nur auf Grundlage des Kontexts.\n\nRegeln:\n- Füge inline-Zitiermarken wie [1], [2] ein, die zu den Quellen passen.\n- Keine separate Quellenliste ausgeben.\n- Antworte knapp und strukturiert auf Deutsch."
REFINE_PROMPT <- "Dies ist ein freundliches Gespräch zwischen Nutzenden und einer KI. Die KI antwortet ausführlich und mit vielen Details aus dem Kontext. Wenn sie etwas nicht weiß, sagt sie das ehrlich.\n\nHier sind die relevanten Dokumente:\n\n{context_msg}\n\nBestehende Antwort:\n{existing_answer}\n\nAnweisung: Verfeinere die bestehende Antwort mithilfe des Kontexts. Wenn der Kontext nicht hilft, wiederhole die bestehende Antwort unverändert."
CITATION_QA_TEMPLATE <- "Bitte beantworte auf Deutsch ausschließlich auf Basis der nummerierten Quellen und füge Inline-Zitate wie [1], [2] ein. Gib keine separate Quellenliste aus.\n------\n{context_str}\n------\nFrage: {query_str}\nAntwort:"
CITATION_REFINE_TEMPLATE <- "Bitte beantworte auf Deutsch ausschließlich auf Basis der nummerierten Quellen und füge Inline-Zitate wie [1], [2] ein. Gib keine separate Quellenliste aus. Wenn die Quellen nicht helfen, wiederhole die bestehende Antwort.\n------\n{context_msg}\n------\nFrage: {query_str}\nBestehende Antwort: {existing_answer}\nVerfeinerte Antwort:"

as_source_list <- function(sources) {
  if (is.null(sources)) {
    return(list())
  }
  if (is.data.frame(sources)) {
    return(lapply(seq_len(nrow(sources)), function(i) {
      as.list(sources[i, , drop = FALSE])
    }))
  }
  if (is.list(sources)) {
    if (length(sources) == 0) {
      return(list())
    }
    if (!is.list(sources[[1]]) && !is.null(names(sources))) {
      return(list(as.list(sources)))
    }
    return(sources)
  }
  list(as.list(sources))
}

# ---- HTTP helpers ---------------------------------------------------------

base_req <- function(path, session_id) {
  req <- request(paste0(BASE_URL, path)) |>
    req_headers(
      `X-Session-Id` = session_id,
      `X-Api-Key` = RAG_SERVICE_API_KEY
    )
  req
}

ingest_async <- function(
  pdf_paths,
  session_id,
  label = NULL,
  filenames = NULL
) {
  parts <- vector("list", length(pdf_paths))
  names(parts) <- rep("files", length(pdf_paths))
  for (i in seq_along(pdf_paths)) {
    fname <- if (!is.null(filenames) && length(filenames) >= i) {
      filenames[[i]]
    } else {
      basename(pdf_paths[[i]])
    }
    parts[[i]] <- curl::form_file(
      pdf_paths[[i]],
      type = "application/pdf",
      name = fname
    )
  }
  if (!is.null(label) && nzchar(label)) {
    parts[["labels"]] <- label
  }
  resp <- base_req("/ingest/async", session_id) |>
    req_body_multipart(!!!parts) |>
    req_perform()
  if (resp_status(resp) >= 300) {
    stop("Ingest start failed: ", resp_body_string(resp))
  }
  resp_body_json(resp)$job_id %||% stop("No job_id returned")
}

clean_html <- function(url) {
  httr2::request(url) |>
    httr2::req_perform() |>
    httr2::resp_body_string() |>
    vns::extract_content_html()
}

ingest_urls_async <- function(url, session_id, label = NULL) {
  html <- clean_html(url)
  name <- basename(url)
  if (!nzchar(name)) {
    name <- "page.html"
  }
  if (!endsWith(tolower(name), ".html")) {
    name <- paste0(name, ".html")
  }
  payload <- list(
    docs = list(list(
      name = name,
      content = html,
      label = if (nzchar(label)) label else name
    ))
  )
  resp <- base_req("/ingest/urls/async", session_id) |>
    req_body_json(payload) |>
    req_perform()
  if (resp_status(resp) >= 300) {
    stop("URL ingest start failed: ", resp_body_string(resp))
  }
  resp_body_json(resp)$job_id %||% stop("No job_id returned")
}

poll_ingest <- function(job_id, session_id) {
  resp <- base_req(paste0("/ingest/status/", job_id), session_id) |>
    req_perform()
  if (resp_status(resp) >= 300) {
    stop("Status failed: ", resp_body_string(resp))
  }
  resp_body_json(resp)
}

delete_documents <- function(label, session_id) {
  resp <- base_req("/chat/delete", session_id) |>
    req_body_json(list(label = label)) |>
    req_perform()
  if (resp_status(resp) >= 300) {
    stop("Löschen fehlgeschlagen: ", resp_body_string(resp))
  }
  invisible(TRUE)
}

chat_stream <- function(
  message,
  session_id,
  history = list(),
  system_prompt = NULL,
  condense_prompt = NULL,
  context_prompt = NULL,
  context_refine_prompt = NULL,
  response_prompt = NULL,
  on_token = NULL
) {
  url <- paste0(BASE_URL, "/chat/stream")
  body <- jsonlite::toJSON(
    list(
      message = message,
      history = history,
      system_prompt = system_prompt,
      condense_prompt = condense_prompt,
      context_prompt = context_prompt,
      context_refine_prompt = context_refine_prompt,
      response_prompt = response_prompt,
      citation_qa_template = CITATION_QA_TEMPLATE,
      citation_refine_template = CITATION_REFINE_TEMPLATE
    ),
    auto_unbox = TRUE,
    null = "null"
  )

  headers <- list(
    "Content-Type" = "application/json",
    "X-Session-Id" = session_id
  )
  if (nzchar(RAG_SERVICE_API_KEY)) {
    headers[["X-Api-Key"]] <- RAG_SERVICE_API_KEY
  }

  acc <- raw(0)
  answer <- ""
  sources <- NULL

  h <- curl::new_handle()
  curl::handle_setheaders(h, .list = headers)
  curl::handle_setopt(h, postfields = body)

  curl::curl_fetch_stream(
    url,
    function(x) {
      acc <<- c(acc, x)
      repeat {
        pos <- match(as.raw(10), acc, nomatch = 0)
        if (pos == 0) {
          break
        }
        line <- rawToChar(acc[seq_len(pos - 1)])
        acc <<- if (pos < length(acc)) acc[(pos + 1):length(acc)] else raw(0)
        if (!nzchar(line)) {
          next
        }
        chunk <- tryCatch(
          jsonlite::fromJSON(line, simplifyVector = FALSE),
          error = function(e) NULL
        )
        if (is.null(chunk)) {
          next
        }
        if (!is.null(chunk$type) && chunk$type == "token") {
          answer <<- paste0(answer, chunk$delta)
          if (!is.null(on_token)) on_token(chunk$delta)
        } else if (!is.null(chunk$type) && chunk$type == "done") {
          if (!is.null(chunk$answer)) {
            answer <<- chunk$answer
          }
          sources <<- as_source_list(chunk$sources)
        } else if (!is.null(chunk$type) && chunk$type == "error") {
          stop("Stream error: ", chunk$error)
        }
      }
    },
    handle = h
  )

  list(answer = answer, sources = as_source_list(sources))
}

# ---- Document listing ----------------------------------------------------

list_documents <- function(session_id) {
  resp <- base_req("/chat/export", session_id) |>
    req_body_json(list(tenant_id = session_id, include_vectors = FALSE)) |>
    req_perform()
  if (resp_status(resp) >= 300) {
    stop("Dokumentenliste fehlgeschlagen: ", resp_body_string(resp))
  }
  data <- resp_body_json(resp)
  pts <- data$points %||% list()
  docs <- lapply(pts, function(p) {
    pl <- p$payload %||% list()
    list(
      label = pl$source_label %||% pl$source_file %||% "Unbenannt",
      source_file = pl$source_file %||% "Unbekannt"
    )
  })
  # Aggregate counts per label
  tab <- table(vapply(docs, function(d) d$label, character(1)))
  out <- lapply(names(tab), function(nm) {
    list(label = nm, count = as.integer(tab[[nm]]))
  })
  out
}
