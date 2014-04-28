# Scrapes season information from Basketball Reference

library(RCurl)
library(XML)

# Input:    End Year (for 1996-97 season, endYear = 1997)
# Output:   Data frame with start dates for Preseason, Regular season,
#           Postseason, and date of All-Star game
scrapeSeason <- function(endYear) {
  output <- as.data.frame(matrix(data = 0, nrow = 1, ncol = 4))
  colnames(output) <- c('endYear', 'regStart', 'postStart', 'allStar')
  output$endYear <- endYear
  
  # URL for regular and postseason start dates
  url1 <- 'http://www.basketball-reference.com/leagues/NBA_'
  url2 <- '_games.html'
  url <- paste(url1, endYear, url2, sep = "")
  tables <- readHTMLTable(url)
  
  # Regular season start date
  output$regStart <- tryCatch({
    df <- data.frame(tables['games'])
    df <- data.frame(lapply(df, as.character), stringsAsFactors = FALSE)
    as.numeric(as.Date(df[1, 1], format = '%a, %b %d, %Y'))
  }, error = function(e) {
    NA
  })
  
  # Postseason start date
  output$postStart <- tryCatch({
    df <- data.frame(tables['games_playoffs'])
    df <- data.frame(lapply(df, as.character), stringsAsFactors = FALSE)
    as.numeric(as.Date(df[1, 1], format = '%a, %b %d, %Y'))
  }, error = function(e) {
    NA
  })
  
  # URL for all-star game date
  url1 <- 'http://www.basketball-reference.com/allstar/NBA_'
  url2 <- '.html'
  url <- paste(url1, endYear, url2, sep = "")
  
  # All-star game date
  output$allStar <- tryCatch({
    content <- readLines(url)
    date <- content[grep('Date:', content)]      # Find line in HTML with date
    date <- as.Date(gsub('.*> ', '', date), format = '%A, %b %d, %Y')
    if (length(date) == 0) {
      NA
    } else {
      as.numeric(date)
    }
  }, error = function(e) {
    NA
  })
  
  return(output)
}

# Input:    Start Season, endSeason (for 1996-97 season, year = 1997)
# Output:   Data frame with start dates for Preseason, Regular season,
#           Postseason, and date of All-Star game for each year
scrapeRange <- function(startSeason, endSeason) {
  df <- data.frame()
  for (i in startSeason:endSeason) {
    df <- rbind(df, scrapeSeason(i))
    cat(i, '\n')
  }
  return(df)
}