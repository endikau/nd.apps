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

# Steht im Ergebnisfeld, solange die aktuellen Eingaben noch nicht analysiert
# wurden – sonst bliebe ein Ergebnis stehen, das nicht mehr dazu passt.
element_result_pending <- htmltools::tags$div(
  class="grid p-3 pb-1",
  htmltools::tags$div(
    class="g-col-1 g-start-xl-3 py-2",
    htmltools::tags$img(
      src="assets/img/2753-blue.svg", height="55pt", width="55pt", alt=""
    )
  ),
  htmltools::tags$div(
    class="g-col-11 g-col-xl-7",
    htmltools::tags$p(
      htmltools::tags$strong(
        style="color: #165a97;", "Noch kein aktuelles Ergebnis"
      )
    ),
    htmltools::tags$p(htmltools::tags$span(stri_c(
      "Die Eingabe hat sich geändert. Klicken Sie auf „Analysieren“, um das ",
      "Ergebnis zu aktualisieren."
    )))
  )
) |> as.character()
