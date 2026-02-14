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
      rows="5", spellcheck="false", example_review)
  ),
  tags$div(
    class="card-footer p-0",
    bslib::input_task_button(
      id="input_doc_random", class="block bg-primary text-white",
      label="Vorschlag generieren",
      icon=icon_fa("fa-solid fa-dice"),
      label_busy="Vorschlag generieren",
      icon_busy=icon_fa("fa-solid fa-sync fa-spin"),
      style=stri_c(
        "width: 100%; padding: 8px 16px; border: 0; ",
        "border-top-left-radius: 0; border-top-right-radius: 0; ",
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
        class="g-col-12 card-body p-0", htmlOutput(outputId="sentidict_score")
      )
    )
  )
)

shiny_ui <- nd.util::nd_page(
  .page_type="app",
  .navbar=NULL,
  .main=list(
    tags$div(
      tags$script(
        "$(document).on('shiny:inputchanged', function(event) {
          if (event.name === 'input_doc_analyze') {
            Shiny.setInputValue(result_invalid, 1);;
          }
        });"
      ),
      element_input_doc,
      # element_input_options,
      tags$div(
        class="my-4",
        bslib::input_task_button(
          id="input_doc_analyze", class="block bg-primary text-white",
          label="Analysieren", icon=icon_fa("fa-solid fa-calculator"),
          label_busy="Analysieren",
          icon_busy=icon_fa("fa-solid fa-sync fa-spin"),
          style="width: 100%; padding: 8px 16px;"
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
