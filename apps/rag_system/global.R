# ---- dependencies & config ------------------------------------------------

APP_DIR <- local({
  source_files <- vapply(sys.frames(), function(frame) {
    file <- frame$ofile
    if (is.null(file)) "" else file
  }, character(1))
  source_files <- source_files[nzchar(source_files)]
  if (length(source_files)) {
    dirname(normalizePath(tail(source_files, 1), mustWork = FALSE))
  } else {
    getwd()
  }
})

app_renviron <- file.path(APP_DIR, ".Renviron")
if (file.exists(app_renviron)) {
  readRenviron(app_renviron)
}

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

`%||%` <- rlang::`%||%`
