
# ============================================================
# PROJECT: The Internet's Memory
# SCRIPT 01: Wikipedia Articles Selection and Validation
# Period: 2023 - 2025
# Languages: 10
# Events: 4
# ============================================================


# 1. LOAD PACKAGE
# ------------------------------------------------------------

library(httr2)
library(tidyverse)


# 2. DEFINE LANGUAGES
# ------------------------------------------------------------

languages <- c(
  "ar", "en", "fr", "es", "de",
  "it", "pt", "tr", "ja", "zh"
)

print(languages)


# 3. DEFINE ARTICLES FOR EACH EVENT
# ------------------------------------------------------------

# EVENT 1: Turkey-Syria Earthquakes (February 2023)

earthquake_articles <- tribble(
  ~event, ~language, ~title,
  "Earthquakes", "ar", "زلزال قهرمان مرعش 2023",
  "Earthquakes", "en", "2023 Turkey–Syria earthquakes",
  "Earthquakes", "fr", "Séismes de 2023 en Turquie et Syrie",
  "Earthquakes", "es", "Terremotos de Turquía y Siria de 2023",
  "Earthquakes", "de", "Erdbeben in der Türkei und Syrien 2023",
  "Earthquakes", "it", "Terremoto in Turchia e Siria del 2023",
  "Earthquakes", "pt", "Sismos da Turquia e Síria de 2023",
  "Earthquakes", "tr", "2023 Kahramanmaraş depremleri",
  "Earthquakes", "ja", "トルコ・シリア地震",
  "Earthquakes", "zh", "2023年土耳其-叙利亚地震"
)


# EVENT 2: Solar Eclipse (April 2024)

eclipse_articles <- tribble(
  ~event, ~language, ~title,
  "Solar Eclipse", "ar", "كسوف الشمس 8 أبريل 2024",
  "Solar Eclipse", "en", "Solar eclipse of April 8, 2024",
  "Solar Eclipse", "fr", "Éclipse solaire du 8 avril 2024",
  "Solar Eclipse", "es", "Eclipse solar del 8 de abril de 2024",
  "Solar Eclipse", "de", "Sonnenfinsternis vom 8. April 2024",
  "Solar Eclipse", "it", "Eclissi solare dell'8 aprile 2024",
  "Solar Eclipse", "pt", "Eclipse solar de 8 de abril de 2024",
  "Solar Eclipse", "ja", "2024年4月8日の日食",
  "Solar Eclipse", "zh", "2024年4月8日日食"
)


# EVENT 3: CrowdStrike Global IT Outage (July 2024)

crowdstrike_articles <- tribble(
  ~event, ~language, ~title,
  "CrowdStrike", "ar", "حادثة كراود سترايك 2024",
  "CrowdStrike", "en", "2024 CrowdStrike-related IT outages",
  "CrowdStrike", "es", "Incidente de CrowdStrike de 2024",
  "CrowdStrike", "it", "Guasto informatico di CrowdStrike del 2024",
  "CrowdStrike", "pt", "Incidente da CrowdStrike em 2024",
  "CrowdStrike", "zh", "2024年CrowdStrike大规模蓝屏事件",
  "CrowdStrike", "fr", "Panne informatique mondiale de juillet 2024",
  "CrowdStrike", "de", "Crowdstrike-Computerausfall 2024"
)


# EVENT 4: FIFA Club World Cup (June-July 2025)

club_world_cup_articles <- tribble(
  ~event, ~language, ~title,
  "FIFA Club World Cup", "en", "2025 FIFA Club World Cup",
  "FIFA Club World Cup", "ar", "كأس العالم للأندية 2025",
  "FIFA Club World Cup", "tr", "2025 FIFA Kulüpler Dünya Kupası",
  "FIFA Club World Cup", "fr", "Coupe du monde des clubs de la FIFA 2025",
  "FIFA Club World Cup", "es", "Copa Mundial de Clubes de la FIFA 2025",
  "FIFA Club World Cup", "de", "FIFA-Klub-Weltmeisterschaft 2025",
  "FIFA Club World Cup", "it", "Coppa del mondo per club FIFA 2025",
  "FIFA Club World Cup", "pt", "Mundial de Clubes FIFA de 2025",
  "FIFA Club World Cup", "zh", "2025年國際足協世界冠軍球會盃",
  "FIFA Club World Cup", "ja", "FIFAクラブワールドカップ"
)


# 4. COMBINE ALL SELECTED ARTICLES
# ------------------------------------------------------------

articles_to_check <- rbind(
  earthquake_articles,
  eclipse_articles,
  crowdstrike_articles,
  club_world_cup_articles
)

print(articles_to_check)

cat("Total selected articles:", nrow(articles_to_check), "\n")


# 5. FUNCTION TO VALIDATE ARTICLE TITLES
# ------------------------------------------------------------

get_page_id <- function(event, lang, article_title) {
  
  url <- paste0(
    "https://", lang, ".wikipedia.org/w/api.php"
  )
  
  for (attempt in 1:5) {
    
    response <- tryCatch({
      
      request(url) |>
        req_url_query(
          action = "query",
          prop = "info",
          titles = article_title,
          format = "json"
        ) |>
        req_user_agent("InternetMemoryEDA/1.0") |>
        req_perform()
      
    }, error = function(e) NULL)
    
    if (!is.null(response)) {
      
      result <- resp_body_json(response)
      
      page <- result$query$pages[[1]]
      
      Sys.sleep(2)
      
      return(tibble(
        event = event,
        language = lang,
        title = page$title,
        pageid = if (is.null(page$pageid)) {
          NA_integer_
        } else {
          page$pageid
        },
        missing = isTRUE(page$missing)
      ))
    }
    
    cat(
      "Request failed. Attempt:",
      attempt,
      "- Article:",
      article_title,
      "\n"
    )
    
    Sys.sleep(10 * attempt)
  }
  
  stop(
    paste("Failed to retrieve:", article_title)
  )
}


# 6. VALIDATE ALL ARTICLES
# ------------------------------------------------------------

articles_check <- do.call(
  rbind,
  lapply(seq_len(nrow(articles_to_check)), function(i) {
    
    get_page_id(
      articles_to_check$event[i],
      articles_to_check$language[i],
      articles_to_check$title[i]
    )
    
  })
)

print(articles_check)


# 7. CHECK MISSING ARTICLES
# ------------------------------------------------------------

missing_articles <- articles_check[
  articles_check$missing == TRUE,
]

print(missing_articles)

cat(
  "Number of missing articles:",
  nrow(missing_articles),
  "\n"
)


# 8. KEEP ONLY VALID ARTICLES
# ------------------------------------------------------------

articles_all <- articles_check[
  articles_check$missing == FALSE,
  c("event", "language", "title", "pageid")
]

print(articles_all)


# 9. CHECK DUPLICATES
# ------------------------------------------------------------

duplicates <- articles_all[
  duplicated(articles_all[c("event", "language")]),
]

print(duplicates)

cat(
  "Number of duplicate rows:",
  nrow(duplicates),
  "\n"
)


# 10. FINAL SUMMARY
# ------------------------------------------------------------

cat("\nFINAL DATASET SUMMARY\n")

cat(
  "Total valid articles:",
  nrow(articles_all),
  "\n"
)

print(table(articles_all$event))

print(table(articles_all$language))


# 11. EXPORT FINAL DATASET
# ------------------------------------------------------------

write.csv(
  articles_all,
  "articles_all.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat(
  "\nFile exported successfully:",
  file.exists("articles_all.csv"),
  "\n"
)

# ============================================================
# END OF SCRIPT 01
# ============================================================
