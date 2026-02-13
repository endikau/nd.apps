library(shiny)
library(callr)

function(input, output, session) {

  .tok_senti_tbl_start <- vns::calc_tok_sentidict_tbl(
    .doc_str=example_review, .sentidict_tbl=vns.data::sentiws_tbl
  )

  .senti_dict_tbl_rct <- reactiveVal(vns.data::sentiws_tbl)
  .doc_str_rct <- reactiveVal(example_review)
  .tok_senti_tbl_rct <- reactiveVal(.tok_senti_tbl_start)

  observeEvent(input$input_senti_dict, {

    if(input$input_senti_dict == "SentiWS"){
      .senti_dict_tbl_rct(vns.data::sentiws_tbl)
    }else if(input$input_senti_dict == "German Polarity Clues"){
      .senti_dict_tbl_rct(vns.data::gerpolclu_tbl)
    }

  })

  observeEvent(input$input_doc_random, {

    updateTextInput(
      session=session, inputId="input_doc_text", value=random_review()
    )

  })

  observeEvent(input$input_doc_analyze, {

    .doc_str_rct(input$input_doc_text)

    .tok_senti_tbl_rct(
      vns::calc_tok_sentidict_tbl(
        .doc_str=input$input_doc_text, .sentidict_tbl=.senti_dict_tbl_rct()
      )
    )

  })
  
  ##############################################################################
  ## OUTPUT ####################################################################
  ##############################################################################

  output$sentidict_score <- renderText({

    if(is.null(.tok_senti_tbl_rct())){return(NULL)}
    
    .tok_senti_tbl_rct() |>
      slice_min(doc_id, n=1, with_ties=TRUE) |>
      group_by(doc_id) |>
      summarize(doc_stat_ui = tok_pol_num |> (\(.tok_pol_num){

        .doc_pol_num <- `/`(
          sum(.tok_pol_num, na.rm=TRUE),
          `+`(
            sum(.tok_pol_num != 0, na.rm=TRUE), 
            log(1 + sum(.tok_pol_num == 0, na.rm=TRUE))
          )
        )

        .doc_pol_lab <- .doc_pol_num |>
          rlang::set_names() |>
          cut.default(
            breaks=c(-1, -0.025, -0.010, -0.002, 0.002, 0.010, 0.025, 1),
            labels=c(
              "sen-neg-max", "sen-neg-med", "sen-neg-min", "sen-neu",
              "sen-pos-min", "sen-pos-med", "sen-pos-max"
            ),
            include.lowest=TRUE
          ) |>
          as.character()

        .doc_pol_color <- .doc_pol_lab |> case_match(
          "sen-pos-max"~"#009392",
          "sen-pos-med"~"#39b185",
          "sen-pos-min"~"#9ccb86",
          "sen-neu"~"#e9e29c",
          "sen-neg-min"~"#eeb479",
          "sen-neg-med"~"#e88471",
          "sen-neg-max"~"#cf597e",
          "sen-miss"~"#bababa",
          .default=NA_character_
        )

        .doc_pol_bg <-
          .doc_pol_color |>
          colorspace::lighten(0.9) |>
          colorspace::desaturate(0.5)

        .doc_pol_emoji <- .doc_pol_lab |> case_match(
          "sen-pos-max"~"assets/img/1f60d.svg",
          "sen-pos-med"~"assets/img/1f600.svg",
          "sen-pos-min"~"assets/img/1f642.svg",
          "sen-neu"~"assets/img/1f610.svg",
          "sen-neg-min"~"assets/img/1fae4.svg",
          "sen-neg-med"~"assets/img/1f97a.svg",
          "sen-neg-max"~"assets/img/1f62d.svg",
          .default=NA_character_
        )

        .doc_pol_text <- .doc_pol_lab |> case_match(
          "sen-pos-max"~"Sehr positive Stimmung",
          "sen-pos-med"~"Positive Stimmung",
          "sen-pos-min"~"Schwach positive Stimmung",
          "sen-neu"~"Neutrale Stimmung",
          "sen-neg-min"~"Schwach negative Stimmung",
          "sen-neg-med"~"Negative Stimmung",
          "sen-neg-max"~"Sehr negative Stimmung",
          .default=NA_character_
        )

        list(tags$div(
          class="grid p-3 pb-1",
          tags$div(
            class="g-col-1 g-start-xl-3 py-2",
            tags$img(src=.doc_pol_emoji, height="55pt", width="55pt")
          ),
          tags$div(
            class="g-col-11 g-col-xl-7",
            tags$p(
              tags$strong(
                style=glue::glue("color: {.doc_pol_color};"), .doc_pol_text
              )
            ),
            tags$p(
              tags$span(
                "Sentimentwert:",
                scales::label_number(
                  accuracy=0.001, style_positive="plus", style_negative="minus"
                )(.doc_pol_num)
              )
            )
          )
        ))

      })()) |>
      pluck("doc_stat_ui", 1) |>
      as.character()
  })

  output$sentidict_text <- renderText({

    if(is.null(.tok_senti_tbl_rct())){return(NULL)}

    .tok_senti_tbl_rct() |>
      mutate(
        tok_pol_lab =
          tok_pol_lab |>
          (`[<-`)(
            i=`&`(
              tok_pol_lab == "sen-miss",
              stringi::stri_detect_regex(tok_str, "[[:alpha:]]")
            ),
            value="sen-neu"
          ) |>
          (`[<-`)(
            i=stringi::stri_detect_regex(tok_str, "[[:space:]]"),
            value=NA_integer_
          ) |>
          vctrs::vec_fill_missing(direction="updown"),
        tok_pol_lab_interval = cumsum(
          `&`(
            tidyr::replace_na(tok_pol_lab != lag(tok_pol_lab), FALSE),
            stringi::stri_detect_regex(lag(tok_str), "[^[:space:]]")
          )
        )
      ) |>
      summarize(
        text_str = stringi::stri_trim_both(
          stringi::stri_c(tok_str, collapse="")
        ),
        text_pol_lab = unique(as.character(tok_pol_lab)),
        .by=tok_pol_lab_interval
      ) |>
      mutate(
        text_pol_col = text_pol_lab |> as.character() |> case_match(
          "sen-pos-max"~"#009392",
          "sen-pos-med"~"#39b185",
          "sen-pos-min"~"#9ccb86",
          "sen-neu"~"#e9e29c",
          "sen-neg-min"~"#eeb479",
          "sen-neg-med"~"#e88471",
          "sen-neg-max"~"#cf597e",
          "sen-miss"~"#bababa"
        )
      ) |>
      purrr::transpose() |>
      purrr::map_chr(\(.tok_data){
        stringi::stri_c(
          "<span class='", .tok_data$text_pol_lab, "' style='padding: 1pt 2pt;'>",
          .tok_data$text_str, "</span>"
        )
      }) |>
      stringi::stri_c(collapse="") |>
      (\(.x){stringi::stri_c("<div class='content-sec'><p lang='de'>", .x, "</p></div>")})()

  })
  outputOptions(output, "sentidict_text", suspendWhenHidden=FALSE)

}
