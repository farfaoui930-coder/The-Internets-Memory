
# ============================================================
# PROJECT: THE INTERNET'S MEMORY
# SCRIPT 02: WIKIMEDIA PAGEVIEWS DATA COLLECTION
# Period: 2023-01-01 to 2025-12-31
# ============================================================


# ------------------------------------------------------------
# 1. Load packages
# ------------------------------------------------------------

library(httr2)
library(tidyverse)


# ------------------------------------------------------------
# 2. Define collection period
# ------------------------------------------------------------

start_date <- "20230101"
end_date   <- "20251231"


# ------------------------------------------------------------
# 3. Import validated Wikipedia articles
# ------------------------------------------------------------

articles_all <- read.csv(
  "articles_all.csv",
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8"
)

print(dim(articles_all))
print(head(articles_all))

stopifnot(nrow(articles_all) == 37)


# ------------------------------------------------------------
# 4. Create an empty pageviews dataset
# ------------------------------------------------------------

empty_pageviews <- function() {
  
  tibble(
    event = character(),
    language = character(),
    title = character(),
    pageid = numeric(),
    timestamp = character(),
    views = integer(),
    date = as.Date(character())
  )
  
}


# ------------------------------------------------------------
# 5. Function to collect pageviews from Wikimedia API
# ------------------------------------------------------------

get_pageviews <- function(lang, title, start, end) {
  
  article_path <- URLencode(
    gsub(" ", "_", title),
    reserved = TRUE
  )
  
  url <- paste0(
    "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/",
    lang,
    ".wikipedia.org/all-access/user/",
    article_path,
    "/daily/",
    start,
    "/",
    end
  )
  
  max_attempts <- 5
  
  for (attempt in seq_len(max_attempts)) {
    
    response <- tryCatch(
      
      request(url) |>
        req_user_agent("InternetMemoryEDA/1.0") |>
        req_timeout(60) |>
        req_error(is_error = function(resp) FALSE) |>
        req_perform(),
      
      error = function(e) NULL
      
    )
    
    # Handle connection errors
    
    if (is.null(response)) {
      
      if (attempt < max_attempts) {
        
        wait_time <- 15 * attempt
        
        message(
          "Connection error. Waiting ",
          wait_time,
          " seconds..."
        )
        
        Sys.sleep(wait_time)
        
        next
        
      } else {
        
        stop("Connection failed after 5 attempts.")
        
      }
      
    }
    
    status_code <- resp_status(response)
    
    
    # HTTP 200: successful request
    
    if (status_code == 200) {
      break
    }
    
    
    # HTTP 404: no data available for this request
    
    if (status_code == 404) {
      
      return(
        tibble(
          timestamp = character(),
          views = integer(),
          date = as.Date(character())
        )
      )
      
    }
    
    
    # HTTP 429: rate limit
    
    if (status_code == 429) {
      
      if (attempt < max_attempts) {
        
        wait_time <- 30 * attempt
        
        message(
          "HTTP 429. Waiting ",
          wait_time,
          " seconds before retry..."
        )
        
        Sys.sleep(wait_time)
        
        next
        
      } else {
        
        stop("HTTP error: 429 after 5 attempts.")
        
      }
      
    }
    
    
    # HTTP 5xx: server errors
    
    if (status_code >= 500 && status_code < 600) {
      
      if (attempt < max_attempts) {
        
        wait_time <- 15 * attempt
        
        message(
          "Server error: ",
          status_code,
          ". Waiting ",
          wait_time,
          " seconds..."
        )
        
        Sys.sleep(wait_time)
        
        next
        
      } else {
        
        stop(
          paste(
            "Server error after 5 attempts:",
            status_code
          )
        )
        
      }
      
    }
    
    
    # Other HTTP errors
    
    stop(
      paste("HTTP error:", status_code)
    )
    
  }
  
  
  # Check final response
  
  if (resp_status(response) != 200) {
    
    stop("Request failed.")
    
  }
  
  
  # Extract JSON response
  
  data <- resp_body_json(response)
  
  
  if (
    is.null(data$items) ||
    length(data$items) == 0
  ) {
    
    return(
      tibble(
        timestamp = character(),
        views = integer(),
        date = as.Date(character())
      )
    )
    
  }
  
  
  # Convert API response into a tibble
  
  result <- tibble(
    
    timestamp = vapply(
      data$items,
      function(x) as.character(x$timestamp),
      character(1)
    ),
    
    views = vapply(
      data$items,
      function(x) as.integer(x$views),
      integer(1)
    )
    
  )
  
  
  # Convert timestamp into Date format
  
  result$date <- as.Date(
    substr(result$timestamp, 1, 8),
    format = "%Y%m%d"
  )
  
  
  return(result)
  
}


# ------------------------------------------------------------
# 6. Function to collect one article
# ------------------------------------------------------------

collect_one_article <- function(event, lang, title, pageid) {
  
  message(
    "Collecting: ",
    lang,
    " - ",
    title
  )
  
  result <- tryCatch({
    
    data <- get_pageviews(
      lang,
      title,
      start_date,
      end_date
    )
    
    
    if (nrow(data) > 0) {
      
      data$event <- event
      data$language <- lang
      data$title <- title
      data$pageid <- pageid
      
      data <- data[
        c(
          "event",
          "language",
          "title",
          "pageid",
          "timestamp",
          "views",
          "date"
        )
      ]
      
      status <- "success"
      
    } else {
      
      data <- empty_pageviews()
      
      status <- "no_data"
      
    }
    
    
    list(
      
      data = data,
      
      status = tibble(
        event = event,
        language = lang,
        title = title,
        pageid = pageid,
        status = status,
        rows = nrow(data),
        error_message = NA_character_
      )
      
    )
    
  }, error = function(e) {
    
    list(
      
      data = empty_pageviews(),
      
      status = tibble(
        event = event,
        language = lang,
        title = title,
        pageid = pageid,
        status = "error",
        rows = 0L,
        error_message = conditionMessage(e)
      )
      
    )
    
  })
  
  
  return(result)
  
}


# ------------------------------------------------------------
# 7. Collect pageviews for all articles
# ------------------------------------------------------------

all_results <- vector(
  "list",
  nrow(articles_all)
)


for (i in seq_len(nrow(articles_all))) {
  
  article_result <- collect_one_article(
    
    event = articles_all$event[i],
    
    lang = articles_all$language[i],
    
    title = articles_all$title[i],
    
    pageid = articles_all$pageid[i]
    
  )
  
  
  all_results[[i]] <- article_result
  
  
  message(
    "Progress: ",
    i,
    " / ",
    nrow(articles_all)
  )
  
  
  # Wait between requests to reduce rate limiting
  
  if (i < nrow(articles_all)) {
    Sys.sleep(10)
  }
  
}


# ------------------------------------------------------------
# 8. Combine all pageviews datasets
# ------------------------------------------------------------

pageviews_list <- lapply(
  all_results,
  function(x) x$data
)


pageviews_list <- pageviews_list[
  vapply(
    pageviews_list,
    nrow,
    integer(1)
  ) > 0
]


if (length(pageviews_list) > 0) {
  
  pageviews_all <- do.call(
    rbind,
    pageviews_list
  )
  
} else {
  
  pageviews_all <- empty_pageviews()
  
}


# ------------------------------------------------------------
# 9. Combine collection status
# ------------------------------------------------------------

pageviews_status <- do.call(
  rbind,
  lapply(
    all_results,
    function(x) x$status
  )
)


# ------------------------------------------------------------
# 10. Export CSV files
# ------------------------------------------------------------

write.csv(
  pageviews_all,
  "pageviews_all.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


write.csv(
  pageviews_status,
  "pageviews_status.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# ------------------------------------------------------------
# 11. Collection summary
# ------------------------------------------------------------

cat("\n========== COLLECTION SUMMARY ==========\n")

cat(
  "Number of articles:",
  nrow(articles_all),
  "\n"
)

cat(
  "Number of pageviews rows:",
  nrow(pageviews_all),
  "\n"
)

cat("\nCollection status:\n")

print(
  table(pageviews_status$status)
)

cat("\nPageviews data dimensions:\n")

print(
  dim(pageviews_all)
)

cat("\nFirst rows of pageviews:\n")

print(
  head(pageviews_all)
)


# ------------------------------------------------------------
# 12. Initial data quality checks
# ------------------------------------------------------------

cat("\n========== DATA QUALITY CHECKS ==========\n")


# Missing values

cat("\nMissing values:\n")

print(
  colSums(is.na(pageviews_all))
)


# Duplicate observations

cat("\nDuplicate observations:\n")

print(
  sum(
    duplicated(
      pageviews_all[
        ,
        c(
          "event",
          "language",
          "title",
          "date"
        )
      ]
    )
  )
)


# Number of articles by event

cat("\nArticles by event:\n")

print(
  table(pageviews_status$event)
)


# Number of observations by event

cat("\nObservations by event:\n")

print(
  table(pageviews_all$event)
)


cat("\n========== COLLECTION COMPLETED ==========\n")
