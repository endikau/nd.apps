library(shiny)
library(arrow)
library(htmltools)

shiny::addResourcePath("assets", here::here("nd.assets", "assets"))

file_path <- "fixed_SMALL_google_news_sentiment.parquet"
data <- read_parquet(file_path)

# Colors for entities
# entity_colors <- c(
#   LOC = "lightblue",
#   PER = "lightgreen",
#   ORG = "lightcoral",
#   MISC = "lightyellow"
# )

entity_colors <- c(
  LOC = "#009392",
  PER = "#cf597e",
  ORG = "#837591",
  MISC = "#777777"
)

# limit text to max 250 (+ end of sentence)
truncate_to_sentence_after_limit <- function(text, n = 250) {
  if (is.null(text) || is.na(text)) return(text)

  word_starts <- gregexpr("\\S+", text, perl = TRUE)[[1]]
  if (length(word_starts) == 1 && word_starts[1] == -1) return(text)
  if (length(word_starts) <= n) return(text)

  cutoff_pos <- word_starts[n]

  tail_text <- substr(text, cutoff_pos, nchar(text))
  dot_rel <- regexpr("\\.", tail_text, perl = TRUE)

  if (dot_rel[1] > 0) {
    end_pos <- cutoff_pos + dot_rel[1] - 1
    return(substr(text, 1, end_pos))
  } else {
    words <- unlist(strsplit(text, "\\s+"))
    return(paste(c(words[1:n], "..."), collapse = " "))
  }
}

highlight_entities <- function(text, entities) {
  if (is.null(text) || is.na(text) || is.null(entities) || nrow(entities) == 0)
    return(text)

  entities <- entities[
    order(nchar(entities$word), decreasing = TRUE),
    ,
    drop = FALSE
  ]

  for (j in seq_len(nrow(entities))) {
    word <- entities$word[j]
    if (is.na(word) || !nzchar(word)) next

    entity_group <- entities$entity_group[j]
    color <- entity_colors[[entity_group]]
    if (is.null(color)) color <- "yellow"

    # Escape regex special chars
    escaped <- gsub(
      "([\\.^$|()\\[\\]{}*+?\\\\-])",
      "\\\\\\1",
      word,
      perl = TRUE
    )
    # Case-insensitive, match as a standalone token (approximate)
    pattern <- paste0("(?i)(?<!\\w)(", escaped, ")(?!\\w)")
    replacement <- sprintf(
      "<mark style='background-color:%s; color: #fefffc; padding:0 3px; border-radius:3px;'>\\1</mark>",
      color
    )

    text <- gsub(pattern, replacement, text, perl = TRUE)
  }
  text
}

if (!"highlighted_content" %in% names(data))
  data$highlighted_content <- NA_character_
for (i in seq_len(nrow(data))) {
  raw_content <- data$Content[i]
  truncated <- truncate_to_sentence_after_limit(raw_content, 250)
  ents_i <- data$entities[[i]]
  data$highlighted_content[i] <- highlight_entities(truncated, ents_i)
}

# UI
ui <- nd.util::nd_page(
  .page_type = "app",
  .navbar = NULL,
  .main = list(
    tags$style(HTML(
      "
      .ner-card { border: 1px solid #eee; border-radius: 12px; padding: 16px; }
      .ner-title { margin: 0 0 4px 0; font-size: 1.2rem; line-height: 1.25; }
      .ner-meta { font-size: 0.9rem; color: #666; margin-bottom: 12px; }
      .ner-legend span { padding: 3px 8px; margin: 3px; border-radius: 4px; display: inline-block; }
    "
    )),
    tags$div(
      class = "d-grid mb-4",
      nd.util::nd_button_block(
        .id = "generate",
        .label = "Zufälliger Google News Artikel",
        .fa_class = "fa-solid fa-dice",
        .fa_class_busy = "fa-solid fa-dice fa-spin"
      )
    ),
    uiOutput("article_output"),
    htmltools::suppressDependencies("font-awesome")
  )
)

# Server
server <- function(input, output, session) {
  current <- reactiveVal(NULL)

  observeEvent(input$generate, {
    row <- data[sample(nrow(data), 1), ]

    card <- tags$div(
      class = "ner-card",
      tags$h3(
        class = "ner-title",
        tags$a(
          href = row$Source_Link,
          target = "_blank",
          rel = "noopener",
          row$Title_x
        )
      ),
      tags$div(
        class = "ner-meta",
        if (!is.null(row$keyword) && nzchar(row$keyword))
          tags$span(paste0("Keyword: ", row$keyword))
      ),
      HTML(row$highlighted_content %||% ""),
      tags$div(
        class = "ner-legend mt-3",
        tags$strong("Legende: "),
        tags$span(
          style = stringi::stri_c(
            "background-color: ",
            entity_colors["LOC"],
            "; color: #fefffc;"
          ),
          "LOC (Ortsname)"
        ),
        tags$span(
          style = stringi::stri_c(
            "background-color: ",
            entity_colors["PER"],
            "; color: #fefffc;"
          ),
          "PER (Person)"
        ),
        tags$span(
          style = stringi::stri_c(
            "background-color: ",
            entity_colors["ORG"],
            "; color: #fefffc;"
          ),
          "ORG (Organisation)"
        ),
        tags$span(
          style = stringi::stri_c(
            "background-color: ",
            entity_colors["MISC"],
            "; color: #fefffc;"
          ),
          "MISC (Sonstiges)"
        )
      )
    )

    current(card)
  })

  output$article_output <- renderUI(current())
}

shinyApp(ui, server)
