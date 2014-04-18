library(RCurl)
library(XML)
library(sqldf)

# Initialize database connection
con <- dbConnect(drv = SQLite(), dbname = "nba_data.db")
games <- dbReadTable(con, 'games')
games$type <- 'preseason'             # By default, label every game as preseason

# Create url templates
url.1 <- 'http://www.basketball-reference.com/leagues/NBA_'
url.2 <- '_games.html'

# Loop through each year from the 1996-97 season to the 2012-13 season
for (year in 1997:2013) {
  
  # Create schedule url
  url <- paste(url.1, year, url.2, sep = "")
  
  # Scrape tables and get number of rows in each table
  tables <- readHTMLTable(url)
  n.rows <- unlist(lapply(tables, function(t) dim(t)[1]))
  
  # Get regular season start and end dates
  df <- data.frame(tables['games'])
  df <- data.frame(lapply(df, as.character), stringsAsFactors = FALSE)
  
  regular.start <- as.Date(df[1, 1], format = '%a, %b %d, %Y')
  regular.end <- as.Date(df[nrow(df), 1], format = '%a, %b %d, %Y')
  
  # Get playoff start and end dates
  df <- data.frame(tables['games_playoffs'])
  df <- data.frame(lapply(df, as.character), stringsAsFactors = FALSE)
  
  post.start <- as.Date(df[1, 1], format = '%a, %b %d, %Y')
  post.end <- as.Date(df[nrow(df), 1], format = '%a, %b %d, %Y')
  
  # Fill in game types
  games[which(games$date >= regular.start & games$date <= regular.end), 'type'] <- 'regular season'
  games[which(games$date >= post.start & games$date <= post.end), 'type'] <- 'postseason'
  
  # Heartbeat
  cat(year, '\n')
}

# Change type of All Star games
games[which(games$homeTeamID == 1610616834), 'type'] <- 'all star game'
games[which(games$awayTeamID == 1610616834), 'type'] <- 'all star game'

# DB Checker -- count number of games per season
for (year in 1997:2013) {
  
  # Create start and end dates
  min.date <- paste(year - 1, '-08-02', sep = '')
  max.date <- paste(year, '-08-01', sep = '')
  
  # Count number of games fitting criteria in our db
  reg <- nrow(games[which(games$date >= min.date & games$date <= max.date & games$type == 'regular season'), ])
  post <- nrow(games[which(games$date >= min.date & games$date <= max.date & games$type == 'postseason'), ])
  
  # Print output
  cat(year, "\t", reg, '\t', post, '\n', sep = '')
}

# BBall Reference Checker -- count number of games per season
for (year in 1997:2013) {
  
  # Create schedule url
  url <- paste(url.1, year, url.2, sep = "")
  
  # Scrape tables and get number of rows in each table
  tables <- readHTMLTable(url)
  n.rows <- unlist(lapply(tables, function(t) dim(t)[1]))
  
  # Get number of games in regular season and post season
  reg.df <- data.frame(tables['games'])
  post.df <- data.frame(tables['games_playoffs'])
  
  reg <- nrow(reg.df)
  post <- nrow(post.df)
  
  # Print output
  cat(year, "\t", reg, '\t', post, '\n', sep = '')
}

# Delete old table and create new one with type
dbRemoveTable(conn = con, name = 'games')
dbSendQuery(conn = con,
            "CREATE TABLE IF NOT EXISTS games(
              date VARCHAR(255) NOT NULL, 
              gameID VARCHAR(255) NOT NULL PRIMARY KEY, 
              status VARCHAR(255), 
              homeTeamID BIGINT UNSIGNED NOT NULL, 
              awayTeamID BIGINT UNSIGNED NOT NULL, 
              nationalTV VARCHAR(255), 
              type VARCHAR(255) NOT NULL
              )")
dbWriteTable(con, name = 'games', value = games, row.names = 0, append = TRUE)
