library(shiny)
library(bslib)

################################################################################

icon_fa <- function(.fa_class) {
  htmltools::tags$i(class = .fa_class, role = "resentation")
}

################################################################################

element_input_doc <- tags$div(
  class = "card my-4",
  tags$div(class = "card-header", "Text festlegen"),
  tags$div(
    class = "form-group shiny-input-container z-index-5",
    style = "width: 100%; z-index: 1000;",
    tags$textarea(
      id = "input_doc_text",
      class = "shiny-input-textarea form-control",
      style = stri_c(
        "width:100%; resize:none; border:0; border-radius: 0; ",
        "font-family: var(--bs-font-monospace); padding: 8px 16px;"
      ),
      rows = "5",
      spellcheck = "false",
      example_review
    )
  ),
  tags$div(
    class = "card-footer p-0",
    bslib::input_task_button(
      id = "input_doc_random",
      class = "block bg-primary text-white",
      label = "Vorschlag generieren",
      icon = icon_fa("fa-solid fa-dice"),
      label_busy = "Vorschlag generieren",
      icon_busy = icon_fa("fa-solid fa-sync fa-spin"),
      style = stri_c(
        "width: 100%; padding: 8px 16px; border: 0; ",
        "border-top-left-radius: 0; border-top-right-radius: 0; ",
        "border-bottom-right-radius: var(--bs-border-radius); ",
        "border-bottom-left-radius: var(--bs-border-radius);"
      )
    )
  )
)

element_output_result <- tags$div(
  class = "card",
  tags$div(class = "card-header", "Ergebnis"),
  tags$div(
    class = "",
    tags$div(
      class = "grid",
      style = "row-gap: 0;",
      div(
        class = "g-col-12 card-body p-0",
        htmlOutput(outputId = "sentidict_score")
      )
    )
  )
)

shiny_ui <- nd.util::nd_page(
  .page_type = "app",
  .navbar = NULL,
  .main = list(
    tags$div(
      tags$script(
        "$(document).on('shiny:inputchanged', function(event) {
          if (event.name === 'input_doc_analyze') {
            Shiny.setInputValue(result_invalid, 1);;
          }
        });"
      ),
      element_input_doc,
      tags$div(
        class = "my-4",
        bslib::input_task_button(
          id = "input_doc_analyze",
          class = "block bg-primary text-white",
          label = "Analysieren",
          icon = icon_fa("fa-solid fa-calculator"),
          label_busy = "Analysieren",
          icon_busy = icon_fa("fa-solid fa-sync fa-spin"),
          style = "width: 100%; padding: 8px 16px;"
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
