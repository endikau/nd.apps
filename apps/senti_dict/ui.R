library(shiny)
library(bslib)

################################################################################

icon_fa <- function(.fa_class){
  htmltools::tags$i(class=.fa_class, role="resentation")
}

################################################################################

legend_sentiment <- tags$svg(
  width="100%", height="2.25rem",
  tags$svg(
    y="0",
    height="0.875rem", width="100%", viewBox="0 0 7 1",
    preserveAspectRatio="none",
    tags$rect(x="0", y="0", width="1.01", height="1", fill="#cf597e"),
    tags$rect(x="1", y="0", width="1.01", height="1", fill="#e88471"),
    tags$rect(x="2", y="0", width="1.01", height="1", fill="#eeb479"),
    tags$rect(x="3", y="0", width="1.01", height="1", fill="#e9e29c"),
    tags$rect(x="4", y="0", width="1.01", height="1", fill="#9ccb86"),
    tags$rect(x="5", y="0", width="1.01", height="1", fill="#39b185"),
    tags$rect(x="6", y="0", width="1", height="1.5", fill="#009392"),
  ),
  tags$svg(
    `alignment-baseline`="bottom", y="0%",
    tags$text(
      x="0%", y="2rem", `text-anchor`="start", `font-size`="0.875rem",
      "negativ"
    ),
    tags$text(
      x="50%", y="2rem", `text-anchor`="middle", `font-size`="0.875rem",
      "neutral"
    ),
    tags$text(
      x="100%", y="2rem", `text-anchor`="end", `font-size`="0.875rem",
      "positiv"
    )
  )
)

element_input_doc <- tags$div(
  class="card my-4",
  tags$div(class="card-header", "Text festlegen"),
  tags$div(
    class="form-group shiny-input-container z-index-5",
    style="width: 100%; z-index: 1000;",
    tags$textarea(
      id="input_doc_text", class="shiny-input-textarea form-control",
      style=stri_c(
        "width:100%; resize:none; border:0; border-radius: 0; ",
        "font-family: var(--bs-font-monospace); padding: 8px 16px;"
      ),
      rows="5", spellcheck="false", example_review
    ),
    # tags$div(
    #   id="input_doc_text", 
    #   class="shiny-input-textarea form-control", 
    #   contenteditable="true", 
    #   rows="5", 
    #   spellcheck="false",
    #   style=stri_c(
    #     "width:100%; resize:none; border:0; border-radius: 0; ",
    #     "font-family: var(--bs-font-monospace); padding: 8px 16px;"
    #   ), 
    #   example_review
    # ),
    tags$script(
      "function twemojiParse( element ) {",
      "  twemoji.parse( element, { base: '/assets/vendor/twemoji/', folder: 'svg', ext: '.svg' } ); ",
      "}",
      "const inputDocText = document.getElementById('input_doc_text');",
      "inputDocText.addEventListener('input', function() {",
      "  twemojiParse(inputDocText);",
      "});"
    )
  ),
  tags$div(
    class="card-footer p-0 d-grid",
    nd.util::nd_button_block(
      .id="input_doc_random", 
      .label="Vorschlag generieren",
      .fa_class="fa-solid fa-dice",
      .fa_class_busy="fa-solid fa-sync fa-spin",
      style=stri_c(
        "border: 0; ",
        "border-top-left-radius: 0; ",
        "border-top-right-radius: 0; ",
        "border-bottom-right-radius: var(--bs-border-radius); ",
        "border-bottom-left-radius: var(--bs-border-radius);"
      )
    )
  )
)

element_input_options <- tags$div(
  class="card mt-2",
  tags$div(class="card-header", "Lexikon auswählen"),
  tags$div(
    id="input_senti_dict",
    class="form-group shiny-input-radiogroup p-3",
    role="radiogroup",
    tags$div(
      class="shiny-options-group",
      tags$div(
        class="form-check form-check-inline",
        tags$input(
          class="form-check-input", type="radio", name="input_senti_dict",
          id="input_senti_dict-1", value="SentiWS", checked=NA
        ),
        tags$label(
          class="form-check-label", `for`="input_senti_dict-1", "SentiWS"
        )
      ),
      tags$div(
        class="form-check form-check-inline",
        tags$input(
          class="form-check-input", type="radio", name="input_senti_dict",
          id="input_senti_dict-2", value="German Polarity Clues"
        ),
        tags$label(
          class="form-check-label", `for`="input_senti_dict-2",
          "German Polarity Clues"
        )
      )
    )
  )
)

element_output_result <- tags$div(
  class="card",
  tags$div(class="card-header", "Ergebnis"),
  tags$div(
    class="",
    tags$div(
      class="grid", style="row-gap: 0;",
      div(
        class="g-col-12 card-body p-0",
        htmlOutput(outputId="sentidict_score")
      ),
      tags$div(
        class="accordion g-col-12 pt-0",
        id="accordionExample",
        tags$div(
          class="accordion-item",
          style="border-left: 0; border-bottom: 0; border-right: 0;",
          tags$span(
            class="accordion-header", id="headingOne",
            tags$button(
              class="accordion-button-primary collapsed",
              style=stri_c(
                "border-top-left-radius: 0; border-top-right-radius: 0; ",
                "padding: 8pt 16pt;"
              ),
              type="button", `data-bs-toggle`="collapse",
              `data-bs-target`="#collapseOne", `aria-expanded`="false",
              `aria-controls`="collapseOne", "Erläuterung"
            )
          ),
          tags$div(
            id="collapseOne", class="accordion-collapse collapse",
            `aria-labelledby`="headingOne",
            `data-bs-parent`="#accordionExample",
            tags$div(
              class="accordion-body",
              div(class="g-col-12", uiOutput(outputId="sentidict_text")),
              div(class="g-col-12", legend_sentiment),
              div(class="g-col-12", "...")
            )
          )
        )
      )
    )
  )
)

shiny_ui <- nd.util::nd_page(
  .page_type="app",
  .navbar=NULL,
  .main=list(
    tags$div(
      element_input_doc,
      element_input_options,
      tags$div(
        class="my-4 d-grid",
        nd.util::nd_button_block(
          .id="input_doc_analyze", 
          .label="Analysieren", 
          .fa_class="fa-solid fa-calculator",
          .fa_class_busy="fa-solid fa-sync fa-spin"
        ),
        tags$script("$('#input_doc_analyze').click();")
      ),
      element_output_result
    ),
    htmltools::suppressDependencies("font-awesome")
  )
)

shiny_ui |> htmltools::findDependencies()

shiny_ui
