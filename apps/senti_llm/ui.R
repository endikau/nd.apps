library(shiny)
library(bslib)

################################################################################

icon_fa <- function(.fa_class) {
  htmltools::tags$i(class = .fa_class, role = "presentation")
}

################################################################################

element_input_doc <- tags$div(
  class = "card my-0",
  tags$div(
    class = "card-header d-flex align-items-center justify-content-between gap-2",
    "Text festlegen",
    nd.util::nd_popover(
      .title = "Hinweise zur Eingabe",
      tags$p(
        "Sie können den vorgegebenen Text überschreiben und einen eigenen ",
        "Text analysieren lassen – oder sich mit „Vorschlag generieren“ ein ",
        "zufälliges Beispiel laden."
      ),
      tags$p(
        "Ihr Text wird ausschließlich für den Betrieb dieser App verarbeitet ",
        "und dient allein der Analyse, die Sie hier auslösen."
      ),
      tags$p(
        "Für die Analyse wird er an den LLM-Dienst des HRZ der ",
        "Justus-Liebig-Universität Gießen übermittelt."
      ),
      tags$p(
        class = "mb-0",
        "Er wird nicht dauerhaft gespeichert und nicht zu anderen Zwecken ",
        "ausgewertet. Mit dem Ende Ihrer Sitzung ist die Eingabe nicht mehr ",
        "verfügbar."
      )
    )
  ),
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
  tags$div(
    class = "card-header d-flex align-items-center justify-content-between gap-2",
    "Ergebnis",
    nd.util::nd_popover(
      .title = "Wie das Label zustande kommt",
      tags$p(
        "Die Einschätzung stammt von einem großen Sprachmodell (Gemma), das ",
        "über den LLM-Dienst des HRZ der Justus-Liebig-Universität Gießen ",
        "angesprochen wird."
      ),
      tags$p(
        "Das Modell erhält die Anweisung, die Stimmung des Textes zu ",
        "bestimmen und sich für genau einen der drei Werte negativ, neutral ",
        "oder positiv zu entscheiden. Die Antwort wird in einem festen ",
        "JSON-Format erzwungen, damit nur diese drei Werte zurückkommen ",
        "können."
      ),
      tags$p(
        class = "mb-0",
        "Anders als bei den anderen Verfahren gibt es dabei weder einen ",
        "Zahlenwert noch eine Wahrscheinlichkeit. Das Modell begründet seine ",
        "Wahl nicht, und derselbe Text kann in zwei Durchläufen ",
        "unterschiedlich eingestuft werden."
      )
    )
  ),
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

shiny_ui <- nd.util::nd_app(
  tags$div(
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

shiny_ui |> htmltools::findDependencies()

shiny_ui
