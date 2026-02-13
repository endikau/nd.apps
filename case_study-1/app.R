library(shiny)
library(arrow)
library(jsonlite)

shiny::addResourcePath(
  prefix = "assets",
  directoryPath = here::here("node_modules", "@endikau", "nd_assets", "dist")
)

# Load the Parquet file
file_path <- "fixed_SMALL_google_news_sentiment.parquet"
data <- read_parquet(file_path)

# Define colors for entities
entity_colors <- c(
  LOC = "lightblue",
  PER = "lightgreen",
  ORG = "lightcoral",
  MISC = "lightyellow"
)

# Preprocess data to generate highlighted content
preprocess_data <- function(data) {
  # Initialize highlighted_content column with the original content
  data$highlighted_content <- data$Content

  for (i in seq_len(nrow(data))) {
    content <- data$Content[i]
    entities <- data$entities[[i]] # Extract the tibble of entities for this row

    # Skip rows where content is missing or entities are NULL
    if (is.null(content) || is.na(content)) {
      next
    }
    if (is.null(entities) || nrow(entities) == 0) {
      # No entities for this row, keep original content
      data$highlighted_content[i] <- content
      next
    }

    # Highlight entities in the content
    for (j in seq_len(nrow(entities))) {
      word <- entities$word[j]
      entity_group <- entities$entity_group[j]
      color <- if (!is.null(entity_colors[[entity_group]])) {
        entity_colors[[entity_group]]
      } else {
        "yellow"
      }

      # Replace the word in the content with highlighted HTML
      content <- gsub(
        paste0("\\b", word, "\\b"), # Match exact word
        sprintf("<mark style='background-color: %s;'>%s</mark>", color, word),
        content
      )
    }

    # Save the highlighted content back to the column
    data$highlighted_content[i] <- content
  }

  return(data)
}

# Preprocess the dataset
data <- preprocess_data(data)

# Shiny UI
ui <- nd.util::nd_page(
  .page_type = "app",
  .navbar = NULL,
  .main = list(
    tags$div(
      class = "d-grid mb-4",
      nd.util::nd_button_block(
        .id = "generate",
        .label = "Erhalte einen zufälligen Google News Artikel",
        .fa_class = "fa-solid fa-dice",
        .fa_class_busy = "fa-solid fa-dice fa-spin"
      ),
    ),
    uiOutput("article_output"),
    htmltools::suppressDependencies("font-awesome")
  )
)

# Shiny Server
server <- function(input, output, session) {
  random_article <- reactiveVal(NULL)

  observeEvent(input$generate, {
    # Select a random row
    random_row <- data[sample(nrow(data), 1), ]

    # Create HTML for the article
    article_html <- HTML(sprintf(
      "
      <h2>%s</h2>
      <p><strong>Sentiment:</strong> <span style='color: %s;'>%s</span></p>
      <p><strong>Source:</strong> <a href='%s' target='_blank'>%s</a></p>
      <p><strong>Keyword:</strong> %s</p>
      <p>%s</p>",
      random_row$Title_x,
      if (random_row$Sentiment == "positive") {
        "green"
      } else if (random_row$Sentiment == "neutral") {
        "grey"
      } else {
        "red"
      },
      random_row$Sentiment,
      random_row$Source_Link,
      random_row$Source_Link,
      random_row$keyword,
      random_row$highlighted_content
    ))

    #html Legende für Entitäten
    legend_html <- HTML(
      "
      <div style='margin-top: 20px;'>
        <strong>Legend:</strong>
        <span style='background-color: lightblue; padding: 3px 8px; margin: 5px;'>LOC (Location)</span>
        <span style='background-color: lightgreen; padding: 3px 8px; margin: 5px;'>PER (Person)</span>
        <span style='background-color: lightcoral; padding: 3px 8px; margin: 5px;'>ORG (Organization)</span>
        <span style='background-color: lightyellow; padding: 3px 8px; margin: 5px;'>MISC (Miscellaneous)</span>
      </div>
    "
    )

    # Combine the article and the legend
    combined_html <- list(
      HTML(paste(
        as.character(article_html),
        as.character(legend_html),
        sep = "<br/>"
      )),
      tags$div(
        class = "pt-4",
        tags$p(
          "Unter ",
          tags$strong("„Sentiment“"),
          " sehen Sie, wie unsere automatisierte Analyse Nachrichtenartikel in positiv, neutral oder negativ klassifiziert. Die ",
          tags$strong("„Source“"),
          " gibt an, aus welcher Ursprungsquelle der Artikel stammt – direkt aus dem Google News-Feed für einen bestimmten Suchbegriff."
        ),
        tags$p(
          "Zusätzlich hebt unsere automatisierte Analyse die wichtigsten Entitäten hervor:"
        ),
        tags$ul(
          tags$li(
            tags$span(
              style = "background-color: lightblue; padding: 2px 6px;",
              "Blau"
            ),
            " für Ortsnamen"
          ),
          tags$li(
            tags$span(
              style = "background-color: lightgreen; padding: 2px 6px;",
              "Grün"
            ),
            " für Personennamen"
          ),
          tags$li(
            tags$span(
              style = "background-color: lightcoral; padding: 2px 6px;",
              "Rot"
            ),
            " für Unternehmensnamen"
          ),
          tags$li(
            tags$span(
              style = "background-color: lightyellow; padding: 2px 6px;",
              "Gelb"
            ),
            " für sonstige Eigennamen"
          )
        ),
        tags$p(
          "Ziehen Sie mehrere zufällige Nachrichtenartikel und erleben Sie, wie die automatisierte Sentiment- und Entitätsanalyse exemplarisch funktioniert."
        ),
        tags$p(tags$strong(
          "Haben Sie noch Fragen oder wollen Sie an einer Fallstudie mitmachen? Kontaktieren Sie uns!"
        ))
      )
    )

    # Update the reactive value
    random_article(combined_html)
  })

  output$article_output <- renderUI({
    random_article()
  })
}

# Run the Shiny App
shinyApp(ui, server)
