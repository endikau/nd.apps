library(shiny)
library(callr)
# library(future)
# library(promises)

# plan(multisession)

function(input, output, session) {
  # TODO: find way to trigger event on app load
  .doc_senti_tbl_start <- calc_doc_senti_llm(
    .doc_str = example_review
  )

  .doc_str_rct <- reactiveVal(example_review)
  .doc_senti_tbl_rct <- reactiveVal(.doc_senti_tbl_start)
  .germansentiment_model_rct <- reactiveVal(NULL)
  .calc_doc_germansentiment_tbl_memo_rct <- reactiveVal(NULL)

  observeEvent(input$input_doc_random, {
    updateTextInput(
      session = session,
      inputId = "input_doc_text",
      value = random_review()
    )
  })

  observeEvent(input$input_doc_analyze, {
    .doc_str_rct({
      input$input_doc_text
    })

    .doc_senti_tbl_rct({
      # if(is.null(.germansentiment_model_rct())){
      #   .germansentiment_model_rct(vns::load_germansentiment_model())
      #   # .calc_doc_germansentiment_tbl_memo_rct(
      #   #   memoise::memoise(
      #   #     f=purrr::partial(
      #   #       .f=vns::calc_doc_germansentiment_tbl,
      #   #       .germansentiment_model=.germansentiment_model_rct()
      #   #     ),
      #   #     cache=getShinyOption("cache_pointer")
      #   #   )
      #   # )
      # }

      # vns::calc_doc_germansentiment_tbl(
      #   .doc_str=input$input_doc_text,
      #   .germansentiment_model=.germansentiment_model_rct()
      # )
      print(Sys.info())
      calc_doc_senti_llm(
        .doc_str = input$input_doc_text
      )
    })
  })

  ##############################################################################
  ## OUTPUT ####################################################################
  ##############################################################################

  output$sentidict_score <- renderText({
    if (is.null(.doc_senti_tbl_rct())) {
      return(NULL)
    }

    .doc_senti_tbl_rct() |>
      transpose() |>
      map(\(.pars) {
        # .pars <<- .pars

        .doc_pol_lab <- .pars$doc_class_lab |>
          recode_values(
            "positiv" ~ "sen-pos-med",
            "neutral" ~ "sen-neu",
            "negativ" ~ "sen-neg-med",
            .default = NA_character_
          )

        .doc_pol_color <- .doc_pol_lab |>
          recode_values(
            "sen-pos-max" ~ "#009392",
            "sen-pos-med" ~ "#39b185",
            "sen-pos-min" ~ "#9ccb86",
            "sen-neu" ~ "#e9e29c",
            "sen-neg-min" ~ "#eeb479",
            "sen-neg-med" ~ "#e88471",
            "sen-neg-max" ~ "#cf597e",
            "sen-miss" ~ "#bababa",
            .default = NA_character_
          )

        .doc_pol_bg <-
          .doc_pol_color |>
          colorspace::lighten(0.9) |>
          colorspace::desaturate(0.5)

        .doc_pol_emoji <- .doc_pol_lab |>
          recode_values(
            "sen-pos-max" ~ "assets/img/1f60d.svg",
            "sen-pos-med" ~ "assets/img/1f600.svg",
            "sen-pos-min" ~ "assets/img/1f642.svg",
            "sen-neu" ~ "assets/img/1f610.svg",
            "sen-neg-min" ~ "assets/img/1fae4.svg",
            "sen-neg-med" ~ "assets/img/1f97a.svg",
            "sen-neg-max" ~ "assets/img/1f62d.svg",
            .default = NA_character_
          )

        .doc_pol_text <- .doc_pol_lab |>
          recode_values(
            "sen-pos-max" ~ "Sehr positive Stimmung",
            "sen-pos-med" ~ "Positive Stimmung",
            "sen-pos-min" ~ "Schwach positive Stimmung",
            "sen-neu" ~ "Neutrale Stimmung",
            "sen-neg-min" ~ "Schwach negative Stimmung",
            "sen-neg-med" ~ "Negative Stimmung",
            "sen-neg-max" ~ "Sehr negative Stimmung",
            .default = NA_character_
          )

        list(tags$div(
          class = "grid p-3 pb-1",
          tags$div(
            class = "g-col-1 g-start-xl-3 py-2",
            tags$img(src = .doc_pol_emoji, height = "55pt", width = "55pt")
          ),
          tags$div(
            class = "g-col-11 g-col-xl-7",
            tags$p(
              tags$strong(
                style = glue::glue("color: {.doc_pol_color};"),
                .doc_pol_text
              )
            )
          )
        ))
      }) |>
      pluck(1, 1) |>
      (\(..x) {
        print(..x)
        ..x
      })() |>
      as.character()
  })
}
