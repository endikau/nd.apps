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
shiny::shinyOptions(cache_pointer=cachem::cache_mem())
shiny::addResourcePath(
  prefix = "assets",
  directoryPath = here::here("node_modules", "@endikau", "nd_assets", "dist")
)

random_review <- function(){
  with(dplyr::slice_sample(vns.data::amazon_review_tbl, n=1), {
    stringi::stri_c(doc_title, ". ", doc_text)
  })
}
