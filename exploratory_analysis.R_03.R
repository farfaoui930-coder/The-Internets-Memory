library(tidyverse)
library(readr)
library(ggplot2)
# ============================================================
# THE INTERNET'S MEMORY
# Script 03: Exploratory Data Analysis
# Wikipedia Pageviews (2023-2025)
# ============================================================


# ------------------------------------------------------------
# 1. Load packages
# ------------------------------------------------------------

library(tidyverse)


# ------------------------------------------------------------
# 2. Load collected data
# ------------------------------------------------------------

articles_all <- read_csv(
  "articles_all.csv",
  show_col_types = FALSE
)

pageviews_all <- read_csv(
  "pageviews_all.csv",
  show_col_types = FALSE
)

# Ensure date has Date format
pageviews_all$date <- as.Date(pageviews_all$date)


# ------------------------------------------------------------
# 3. Initial data checks
# ------------------------------------------------------------

cat("\n========== DATA OVERVIEW ==========\n")

cat("Number of articles:", nrow(articles_all), "\n")
cat("Number of pageview observations:", nrow(pageviews_all), "\n")

cat("\nMissing values:\n")
print(colSums(is.na(pageviews_all)))

cat("\nDuplicate observations:\n")

duplicate_count <- sum(
  duplicated(
    pageviews_all[
      ,
      c("event", "language", "title", "date")
    ]
  )
)

print(duplicate_count)

cat("\nArticles by event:\n")
print(table(articles_all$event))

cat("\nObservations by event:\n")
print(table(pageviews_all$event))


# ------------------------------------------------------------
# 4. Define event calendar
# ------------------------------------------------------------

event_calendar <- tibble(
  event = c(
    "Earthquakes",
    "Solar Eclipse",
    "CrowdStrike",
    "FIFA Club World Cup"
  ),
  
  event_start = as.Date(c(
    "2023-02-06",
    "2024-04-08",
    "2024-07-19",
    "2025-06-14"
  )),
  
  event_end = as.Date(c(
    "2023-02-12",
    "2024-04-14",
    "2024-07-25",
    "2025-07-13"
  ))
)


# ------------------------------------------------------------
# 5. Calculate baseline and event coverage
# ------------------------------------------------------------

coverage_results <- vector(
  "list",
  nrow(articles_all)
)

for (i in seq_len(nrow(articles_all))) {
  
  ev <- articles_all$event[i]
  lang <- articles_all$language[i]
  article <- articles_all$title[i]
  
  event_info <- event_calendar[
    event_calendar$event == ev,
  ]
  
  start_event <- event_info$event_start
  end_event <- event_info$event_end
  
  article_data <- pageviews_all[
    pageviews_all$event == ev &
      pageviews_all$language == lang &
      pageviews_all$title == article,
  ]
  
  baseline_data <- article_data[
    article_data$date >= start_event - 28 &
      article_data$date < start_event,
  ]
  
  event_data <- article_data[
    article_data$date >= start_event &
      article_data$date <= end_event,
  ]
  
  baseline_days <- length(unique(baseline_data$date))
  event_days <- length(unique(event_data$date))
  
  expected_event_days <- as.integer(
    end_event - start_event
  ) + 1
  
  coverage_results[[i]] <- tibble(
    event = ev,
    language = lang,
    title = article,
    baseline_days = baseline_days,
    event_days = event_days,
    expected_event_days = expected_event_days,
    baseline_complete = baseline_days == 28,
    event_complete = event_days == expected_event_days
  )
}

coverage_windows <- do.call(
  rbind,
  coverage_results
)

cat("\n========== COVERAGE SUMMARY ==========\n")

print(
  table(
    coverage_windows$event,
    coverage_windows$baseline_complete
  )
)

print(
  table(
    coverage_windows$event,
    coverage_windows$event_complete
  )
)


# ------------------------------------------------------------
# 6. Select articles with complete event coverage
# ------------------------------------------------------------

eligible_articles <- coverage_windows[
  coverage_windows$event_complete == TRUE,
]

cat("\nArticles with complete event coverage:\n")
print(table(eligible_articles$event))


# ------------------------------------------------------------
# 7. Calculate Attention Index
# Only articles with complete baseline and event coverage
# ------------------------------------------------------------

valid_index_articles <- eligible_articles[
  eligible_articles$baseline_complete == TRUE,
]

attention_results <- vector(
  "list",
  nrow(valid_index_articles)
)

for (i in seq_len(nrow(valid_index_articles))) {
  
  ev <- valid_index_articles$event[i]
  lang <- valid_index_articles$language[i]
  article <- valid_index_articles$title[i]
  
  event_info <- event_calendar[
    event_calendar$event == ev,
  ]
  
  start_event <- event_info$event_start
  end_event <- event_info$event_end
  
  article_data <- pageviews_all[
    pageviews_all$event == ev &
      pageviews_all$language == lang &
      pageviews_all$title == article,
  ]
  
  baseline_data <- article_data[
    article_data$date >= start_event - 28 &
      article_data$date < start_event,
  ]
  
  event_data <- article_data[
    article_data$date >= start_event &
      article_data$date <= end_event,
  ]
  
  baseline_mean <- mean(baseline_data$views)
  event_mean <- mean(event_data$views)
  
  attention_results[[i]] <- tibble(
    event = ev,
    language = lang,
    baseline_mean = baseline_mean,
    event_mean = event_mean,
    attention_index = (
      event_mean / baseline_mean
    ) * 100
  )
}

attention_index <- do.call(
  rbind,
  attention_results
)

attention_index$increase_percent <-
  attention_index$attention_index - 100

attention_index <- attention_index[
  order(
    attention_index$event,
    -attention_index$attention_index
  ),
]

cat("\n========== ATTENTION INDEX ==========\n")
print(attention_index, n = 18)


# ------------------------------------------------------------
# 8. Visualization 1
# Total pageviews by event and language
# ------------------------------------------------------------

views_by_event_language <- aggregate(
  views ~ event + language,
  data = pageviews_all,
  FUN = sum
)

plot1 <- ggplot(
  views_by_event_language,
  aes(
    x = language,
    y = log10(views),
    fill = event
  )
) +
  geom_col() +
  facet_wrap(
    ~ event,
    scales = "free_y"
  ) +
  labs(
    title = "Wikipedia Attention Across Languages",
    subtitle = "Total pageviews by event and language (2023-2025)",
    x = "Wikipedia language",
    y = "Log10 of total pageviews",
    fill = "Event"
  ) +
  theme_minimal() +
  theme(
    legend.position = "none",
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    plot.title = element_text(face = "bold")
  )

print(plot1)


# ------------------------------------------------------------
# 9. Visualization 2
# Relative attention across languages
# ------------------------------------------------------------

plot2 <- ggplot(
  attention_index,
  aes(
    x = reorder(language, attention_index),
    y = attention_index,
    fill = event
  )
) +
  geom_col() +
  facet_wrap(
    ~ event,
    scales = "free_x"
  ) +
  coord_flip() +
  geom_hline(
    yintercept = 100,
    linetype = "dashed"
  ) +
  labs(
    title = "Relative Attention Across Languages",
    subtitle = "Attention Index: 100 = pre-event baseline",
    x = "Wikipedia language",
    y = "Attention Index",
    fill = "Event"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

print(plot2)


# ------------------------------------------------------------
# 10. Prepare daily views around each event
# ------------------------------------------------------------

relative_views_results <- vector(
  "list",
  nrow(event_calendar)
)

for (i in seq_len(nrow(event_calendar))) {
  
  ev <- event_calendar$event[i]
  start_event <- event_calendar$event_start[i]
  end_event <- event_calendar$event_end[i]
  
  event_data <- pageviews_all[
    pageviews_all$event == ev &
      pageviews_all$date >= start_event - 28 &
      pageviews_all$date <= end_event + 14,
  ]
  
  daily_data <- aggregate(
    views ~ date,
    data = event_data,
    FUN = sum
  )
  
  daily_data$event <- ev
  
  daily_data$days_from_event <- as.integer(
    daily_data$date - start_event
  )
  
  relative_views_results[[i]] <- daily_data
}

relative_views <- do.call(
  rbind,
  relative_views_results
)


# ------------------------------------------------------------
# 11. Visualization 3
# Daily attention around each event
# ------------------------------------------------------------

plot3 <- ggplot(
  relative_views,
  aes(
    x = days_from_event,
    y = views
  )
) +
  geom_line(linewidth = 0.6) +
  geom_vline(
    xintercept = 0,
    linetype = "dashed"
  ) +
  facet_wrap(
    ~ event,
    scales = "free_y",
    ncol = 2
  ) +
  coord_cartesian(
    xlim = c(-28, 44)
  ) +
  labs(
    title = "How Global Events Capture Attention",
    subtitle = "Daily Wikipedia pageviews around each event",
    x = "Days from event start (Day 0)",
    y = "Total daily pageviews"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold")
  )

print(plot3)


# ------------------------------------------------------------
# 12. Save visualizations
# ------------------------------------------------------------

dir.create(
  "figures",
  showWarnings = FALSE
)

ggsave(
  "figures/plot1_language_attention.png",
  plot = plot1,
  width = 10,
  height = 6,
  dpi = 300
)

ggsave(
  "figures/plot2_attention_index.png",
  plot = plot2,
  width = 10,
  height = 6,
  dpi = 300
)

ggsave(
  "figures/plot3_event_evolution.png",
  plot = plot3,
  width = 10,
  height = 7,
  dpi = 300
)


# ------------------------------------------------------------
# 13. Export analysis tables
# ------------------------------------------------------------

write_csv(
  coverage_windows,
  "coverage_windows.csv"
)

write_csv(
  attention_index,
  "attention_index.csv"
)

write_csv(
  views_by_event_language,
  "views_by_event_language.csv"
)


# ------------------------------------------------------------
# 14. End of analysis
# ------------------------------------------------------------

cat("\n====================================\n")
cat("EXPLORATORY ANALYSIS COMPLETED\n")
cat("3 visualizations saved in figures/\n")
cat("Analysis tables exported successfully\n")
cat("====================================\n")

