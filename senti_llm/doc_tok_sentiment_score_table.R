.doc_str <- "Leider nicht erhalten. Schade, dass der Artikel bis heute noch nicht angekommen ist. Auf mehrmaliges Nachfragen wurde mir zweimal versprochen, dass Ersatz verschickt worden sei. Es kann schon mal vorkommen, dass eine Sendung verloren geht, aber dass drei!!! Warensendungen innerhalb 4 Wochen nicht ankommen, finde ich sehr verwunderlich. Geld wurde zurückerstattet."

vns::calc_doc_sentidict_tbl(.doc_str = .doc_str, vns::sentidict_sws_tbl)

test <- # gt::render_gt({
  vns::calc_tok_sentidict_tbl(.doc_str = .doc_str, vns::sentidict_sws_tbl) |>
  dplyr::filter(tok_pol_lab != "sen-miss") |>
  dplyr::mutate(
    tok_pol_lab = tok_pol_lab |>
      as.character() |>
      dplyr::case_match(
        "sen-pos-max" ~ "#009392",
        "sen-pos-med" ~ "#39b185",
        "sen-pos-min" ~ "#9ccb86",
        "sen-neu" ~ "#e9e29c",
        "sen-neg-min" ~ "#eeb479",
        "sen-neg-med" ~ "#e88471",
        "sen-neg-max" ~ "#cf597e",
        "sen-miss" ~ "#bababa"
      )
  ) |>
  gt::gt() |>
  gt::as_raw_html()

# })

bslib::page_fillable(
  shiny::tags$div(test),
  shiny::tags$div(test)
)
