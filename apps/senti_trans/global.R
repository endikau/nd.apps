if(interactive()){
  setwd("~/Documents/endikau/endikau.shares/apps/senti_trans/")
}

tryCatch(
  expr={vns::use_vns_condaenv()},
  error=\(...){
    vns::setup_vns_condaenv(.install_miniconda=TRUE, .create_condaenv=TRUE)
    vns::use_vns_condaenv()
  }
)

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

options(shiny.autoreload=TRUE)
shiny::shinyOptions(cache_pointer=cachem::cache_disk("./app_cache/"))
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
germansentiment_model <- vns::load_germansentiment_model()

calc_doc_germansentiment_tbl_memo_full <- memoise::memoise(
  f=purrr::partial(
    .f=vns::calc_doc_germansentiment_tbl,
    .germansentiment_model=germansentiment_model
  ),
  cache=getShinyOption("cache_pointer")
)

calc_doc_germansentiment_tbl_memo_each <- function(.doc_str){
  purrr::map_dfr(.doc_str, \(..doc_str){
    calc_doc_germansentiment_tbl_memo_full(..doc_str)
  })
}

random_review <- function(){
  with(dplyr::slice_sample(vns.data::amazon_review_tbl, n=1), {
    stringi::stri_c(doc_title, ". ", doc_text)
  })
}

# color_palette <- jsonlite::read_json(
#   system.file("app", "sentiment_dict", "colors.json", package="endikau.apps")
# )
