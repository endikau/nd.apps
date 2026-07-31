# app.R
library(shiny)
library(quanteda)
library(here)
library(stringi)

shiny::addResourcePath(
  prefix = "assets",
  directoryPath = here::here("node_modules", "@endikau", "nd_assets", "dist")
)

### demo texts (could add a few more)
demo_texts <- c(
  "Uff 😠... der Akku hält keine 3 Stunden mehr nach nur einem Jahr. https://kopfhoerer.de/review",
  "Tolles Design, aber der Lautsprecher rauscht nach 2 Wochen ständig 😕 https://lautsprecher.de/review",
  "Der Kundendienst hat mir super geholfen – da gibt man gerne 5 Sterne! 😊 https://lautsprecher.de/review",
  "Kaum ist die Garantie abgelaufen, geht das Gerät kaputt 👎 Jetzt warte ich seit über 3 Tagen auf eine Antwort vom Kundendienst http://techblog.de/review",
  "Warum dauert die Lieferung so lange? Ich warte nun seit 2 Wochen... 😫 https://techblog.de/review",
  "Nach 5 Tagen war das Paket endlich da 📦 – schneller wäre natürlich besser gewesen! https://versand.de/review",
  "In nur 2 Minuten aufgebaut und sofort einsatzbereit 🔧 – echt praktisch! https://produkt.de/review",
  "Die Schuhe waren nach 2 Tagen eingetragen und sind seitdem super bequem! Fußschmerzen beim Joggen sind damit Geschichte 👟. https://schuhe.de/review",
  "Mit 5 Klicks war die Bestellung abgeschlossen ✅ – super einfach! https://shop.de/review",
  "Bereits nach 6 Stunden leer ⏳ – der Akku hält leider nicht, was er verspricht. https://technik.de/review"
)


### patterns (ICU-Regex, wie von stringi verwendet)
URL_PATTERN <- "(https?://|www\\.)\\S+"
# Ohne \p{Emoji} und \p{Emoji_Component}: die beiden matchen auch die
# ASCII-Ziffern 0-9, "Emojis entfernen" hätte sonst die Zahlen mitgelöscht.
EMOJI_PATTERN <- stringi::stri_c(
  "[\\p{Extended_Pictographic}\\p{Emoji_Presentation}\\uFE0F\\u200D]+"
)
# URLs und Emojis werden beim Entfernen der Satzzeichen geschützt.
PROTECT_PATTERN <- stringi::stri_c(URL_PATTERN, "|", EMOJI_PATTERN)

STEPS <- c(
  "Kleinschreibung" = "lower",
  "Satzzeichen entfernen" = "punct",
  "Zahlen entfernen" = "numbers",
  "URLs entfernen" = "url",
  "Emojis entfernen" = "emoji",
  "Stoppwörter entfernen" = "stopwords",
  "Lemmatisierung" = "lemma",
  "Stemming" = "stem",
  "Tokenisierung" = "token"
)


### lemmatization model (spaCy via reticulate)
# Wird einmal beim Start der App geladen (~5 s); jeder weitere Aufruf von
# parse_doc_spacy() auf einen Demo-Text liegt im Bereich von 0,2 s.
SPACY_MODEL <- vns::load_spacy_model()

lemmatize_text <- function(text) {
  # parse_doc_spacy() bricht bei einer leeren Zeichenkette ab (die Tabelle
  # hat dann keine Spalte doc_id), deshalb vorher abfangen.
  if (stringi::stri_isempty(stringi::stri_trim_both(text))) {
    return("")
  }
  parse_tbl <- vns::parse_doc_spacy(text, .spacy_model = SPACY_MODEL)

  # Satzzeichen tragen bei spaCy das Lemma "--" und müssen raus; die
  # stri_trim-Runde entfernt zusätzlich reine Whitespace-Token.
  lem <- parse_tbl$tok_lemma_str[parse_tbl$tok_pos != "PUNCT"]
  lem <- stringi::stri_trim_both(lem[!is.na(lem)])
  lem <- lem[!stringi::stri_isempty(lem)]
  if (!length(lem)) {
    return("")
  }
  stringi::stri_c(lem, collapse = " ")
}


# helpers
# Satzzeichen überall entfernen, ausser innerhalb der Treffer von
# `protect_pattern` (URLs, Emojis) — dort bleibt der Text unangetastet.
remove_punct_outside <- function(text, protect_pattern) {
  spans <- stringi::stri_locate_all_regex(
    text,
    protect_pattern,
    omit_no_match = TRUE
  )[[1]]

  # geschützte Treffer und die Lücken dazwischen; es gibt immer genau eine
  # Lücke mehr als Treffer (auch bei null Treffern: der ganze Text).
  protected <- stringi::stri_sub(text, spans[, "start"], spans[, "end"])
  gaps <- stringi::stri_sub(
    text,
    c(1L, spans[, "end"] + 1L),
    c(spans[, "start"] - 1L, stringi::stri_length(text))
  )

  stringi::stri_c(
    stringi::stri_replace_all_regex(gaps, "[[:punct:]]", " "),
    c(protected, ""),
    collapse = ""
  )
}

preprocess_text <- function(text, steps) {
  text <- if (is.null(text)) "" else text

  ## Zeichenebene (stringi) — arbeitet auf dem Text als Ganzem und muss
  ## deshalb vor der Tokenisierung laufen. quanteda kann das nicht abdecken:
  ## Es kennt nur Tokens, und aus Tokens lässt sich der Text nicht wieder
  ## herstellen. Dazu erkennt sein `remove_url` internationalisierte Domains
  ## (Umlaut) nicht, `remove_punct` zerlegt solche URLs zusätzlich.
  if ("url" %in% steps) {
    text <- stringi::stri_replace_all_regex(text, URL_PATTERN, "")
  }
  if ("emoji" %in% steps) {
    text <- stringi::stri_replace_all_regex(text, EMOJI_PATTERN, "")
  }
  if ("numbers" %in% steps) {
    text <- stringi::stri_replace_all_regex(text, "[0-9]+", " ")
  }
  if ("punct" %in% steps) {
    text <- remove_punct_outside(text, PROTECT_PATTERN)
  }

  if ("lemma" %in% steps) {
    text <- lemmatize_text(text)
  }

  ## Kleinschreibung bewusst NACH der Lemmatisierung: spaCy normalisiert auf
  ## die Wörterbuchform, und die ist bei deutschen Substantiven groß
  ## ("akku" -> "Akku"). Andersherum hätte die Lemmatisierung die
  ## Kleinschreibung wieder aufgehoben. Nebeneffekt: spaCy bekommt den Text
  ## mit korrekter Groß-/Kleinschreibung und taggt dadurch zuverlässiger.
  if ("lower" %in% steps) {
    text <- stringi::stri_trans_tolower(text)
  }

  ## Tokenebene (quanteda) — erst hier wird tokenisiert, und nur, wenn
  ## wirklich ein Schritt auf Tokenebene gewählt ist. Sonst bliebe schon
  ## ohne jede Auswahl nur der wieder zusammengefügte Text übrig.
  if (any(c("stopwords", "stem", "token") %in% steps)) {
    toks <- quanteda::tokens(text)
    if ("stopwords" %in% steps) {
      # case_insensitive = TRUE: die Stoppwortliste ist durchgehend klein
      # geschrieben. Ohne das würde "Die" am Satzanfang nur dann entfernt,
      # wenn zusätzlich Kleinschreibung gewählt ist.
      toks <- quanteda::tokens_remove(
        toks,
        pattern = vns.data::sword_vec,
        valuetype = "fixed",
        case_insensitive = TRUE
      )
    }
    if ("stem" %in% steps) {
      toks <- quanteda::tokens_wordstem(toks, language = "german")
    }

    tok_vec <- as.character(toks)
    text <- if ("token" %in% steps) {
      stringi::stri_c("[", stringi::stri_c(tok_vec, collapse = "], ["), "]")
    } else {
      stringi::stri_c(tok_vec, collapse = " ")
    }
  }

  text <- stringi::stri_replace_all_regex(text, "\\s+", " ")
  stringi::stri_trim_both(text)
}


# ui
# Karten folgen den senti_*-Apps: keine eigenen Regeln für .card /
# .card-header, Abstand zwischen allen Karten durchgehend 1,5rem (my-4 /
# mt-4), Kopfzeile als Flex-Zeile — damit rechtsbündig ein nd_popover()
# ergänzt werden kann, ohne die Karte umzubauen.

# Die Checkboxen kommen als Bootstrap-5-Markup aus nd.util
# (nd_checkbox() / nd_checkbox_group()) statt aus shiny::checkboxInput().

# Button sitzt bündig in der Kartenfußzeile: kein eigener Rahmen, oben
# eckig (schliesst an die Karte an), unten auf den Kartenradius gerundet.
# Muster von "Vorschlag generieren" aus senti_dict.
CARD_FOOTER_BTN_STYLE <- stringi::stri_c(
  "border: 0; ",
  "border-top-left-radius: 0; ",
  "border-top-right-radius: 0; ",
  "border-bottom-right-radius: var(--bs-border-radius); ",
  "border-bottom-left-radius: var(--bs-border-radius);"
)

ui <- nd.util::nd_app(
  .head = tags$style(HTML(
    "
        /* Abstand kommt allein von .card-body (1rem), wie in der oberen
           Karte. Deshalb hier keine eigene Polsterung — und am <pre> auch
           den margin-bottom: 1rem aus dem Bootstrap-Reboot zuruecknehmen. */
        .text-display, .text-display pre {
          white-space: pre-wrap !important;
          word-break: break-word !important;
          overflow-wrap: anywhere !important;
          font-family: var(--bs-font-monospace);
          line-height: 1.45;
          max-width: 100%; overflow-x: hidden;
        }
        .text-display pre {
          margin: 0;
          padding: 0;
          /* Der Reboot setzt pre auf 0.875em; hier soll die Ausgabe aber
             so gross sein wie der Text der oberen Karte. 1em statt eines
             festen Werts, damit es der Theme-Groesse folgt. */
          font-size: 1em;
        }
        .shiny-input-checkboxgroup .shiny-options-group .form-check {
          margin-bottom: .4rem;
        }
      "
  )),
  tags$div(

    # Karte 1: Auswahl der Schritte
    tags$div(
      class = "card my-0",
      tags$div(
        class = "card-header d-flex align-items-center justify-content-between gap-2",
        "Schritte auswählen"
      ),
      tags$div(
        class = "card-body",
        tags$div(
          class = "border-bottom pb-2 mb-2",
          nd.util::nd_checkbox("select_all", "Alles auswählen", .value = FALSE)
        ),
        nd.util::nd_checkbox_group(
          .id = "steps",
          .choices = STEPS,
          .label = "Schritte auswählen"
        )
      ),
      tags$div(
        class = "card-footer p-0 d-grid",
        nd.util::nd_button_block(
          .id = "reset",
          .label = "Zurücksetzen",
          .fa_class = "fa-solid fa-rotate-left",
          .fa_class_busy = "fa-solid fa-sync fa-spin",
          style = CARD_FOOTER_BTN_STYLE
        )
      )
    ),

    # Karte 2: Ergebnis
    tags$div(
      class = "card mt-4",
      tags$div(
        class = "card-header d-flex align-items-center justify-content-between gap-2",
        "Beispieltext (verarbeitet)"
      ),
      tags$div(
        class = "card-body",
        tags$div(
          class = "text-display text-break",
          verbatimTextOutput("processed_text")
        )
      ),
      tags$div(
        class = "card-footer p-0 d-grid",
        nd.util::nd_button_block(
          .id = "new_example",
          .label = "Neues Beispiel",
          .fa_class = "fa-solid fa-dice",
          .fa_class_busy = "fa-solid fa-sync fa-spin",
          style = CARD_FOOTER_BTN_STYLE
        )
      )
    )
  )
)


# Server
server <- function(input, output, session) {
  # Bei kurzem Verbindungsabbruch (z. B. Proxy schließt idle WebSocket) still
  # zur selben, weiterlaufenden Session reconnecten statt "Disconnected"-Overlay.
  session$allowReconnect(TRUE)

  current_text <- reactiveVal(sample(demo_texts, 1))

  observeEvent(input$new_example, {
    current_text(sample(demo_texts, 1))
  })

  observeEvent(input$reset, {
    updateCheckboxGroupInput(session, "steps", selected = character(0))
    updateCheckboxInput(session, "select_all", value = FALSE)
  })

  observeEvent(input$select_all, {
    updateCheckboxGroupInput(
      session,
      "steps",
      selected = if (isTRUE(input$select_all)) unname(STEPS) else character(0)
    )
  })

  observeEvent(
    input$steps,
    {
      all_selected <- length(input$steps) == length(STEPS)
      if (isTRUE(input$select_all) != all_selected) {
        updateCheckboxInput(session, "select_all", value = all_selected)
      }
    },
    ignoreInit = TRUE
  )

  output$processed_text <- renderText({
    txt <- preprocess_text(current_text(), input$steps)
    if (stringi::stri_isempty(txt)) "(leer)" else txt
  })
}

shinyApp(ui, server)
