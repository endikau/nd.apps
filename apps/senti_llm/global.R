if (interactive()) {
  setwd("~/Documents/endikau/nd.apps/senti_llm/")
}

library(shiny)
library(dplyr)
library(purrr)
library(stringi)

`%||%` <- rlang::`%||%`
stri_c <- stringi::stri_c

example_review <- paste0(
  "Leider nicht erhalten. Schade, dass der Artikel bis heute noch nicht ",
  "angekommen ist. Auf mehrmaliges Nachfragen wurde mir zweimal versprochen, ",
  "dass Ersatz verschickt worden sei. Es kann schon mal vorkommen, dass eine ",
  "Sendung verloren geht, aber dass drei!!! Warensendungen innerhalb 4 Wochen ",
  "nicht ankommen, finde ich sehr verwunderlich. Geld wurde zurückerstattet."
)

options(shiny.autoreload = TRUE)
if (grepl("^hz126", Sys.info()["nodename"])) {
  shiny::shinyOptions(cache_pointer = cachem::cache_disk("cache/"))
} else {
  shiny::shinyOptions(cache_pointer = cachem::cache_mem())
}
shiny::addResourcePath(
  prefix = "assets",
  directoryPath = here::here("node_modules", "@endikau", "nd_assets", "dist")
)
# spacy_model <- vns::load_spacy_model()

# parse_doc_spacy_memo_full <- memoise::memoise(
#   f=purrr::partial(.f=vns::parse_doc_spacy, .spacy_model=spacy_model),
#   cache=getShinyOption("cache_pointer")
# )
#
# parse_doc_spacy_memo_each <- function(.doc_str){
#   purrr::map_dfr(.doc_str, \(..doc_str){
#     parse_doc_spacy_memo_full(..doc_str)
#   })
# }

calc_doc_senti_llm <- function(.doc_str) {
  `%s+%` <- stringi::`%s+%`

  base_url <- "https://api.hrz.uni-giessen.de/v1"

  system_prompt <- "Analysiere das Sentiment des Textes und gib das " %s+%
    "Ergebnis ausschließlich im folgenden JSON-Format zurück:\n" %s+%
    "\n" %s+%
    "```json\n" %s+%
    "{\n" %s+%
    "    \"Sentiment\": \"negativ\" | \"neutral\" | \"positiv\"\n" %s+%
    "}\n" %s+%
    "```\n" %s+%
    "\n" %s+%
    "Wähle genau einen der drei Werte und gib keine weiteren Inhalte zurück."

  chat <- ellmer::chat_openai_compatible(
    model = "gwdg/gemma-3-27b-it",
    base_url = base_url,
    system_prompt = system_prompt
  )

  .doc_str |>
    tibble::as_tibble_col("doc_str") |>
    dplyr::mutate(
      doc_class_lab = ellmer::parallel_chat_structured(
        chat = chat,
        prompts = as.list(.doc_str),
        type = ellmer::type_object(
          Sentiment = ellmer::type_enum(
            values = c("negativ", "neutral", "positiv")
          )
        ),
        max_active = 8
      ) |>
        dplyr::pull(Sentiment) |>
        as.character()
    )
}

random_review <- function() {
  with(dplyr::slice_sample(vns.data::amazon_review_tbl, n = 1), {
    stringi::stri_c(doc_title, ". ", doc_text)
  })
}

# color_palette <- jsonlite::read_json(
#   system.file("app", "sentiment_dict", "colors.json", package="endikau.apps")
# )
