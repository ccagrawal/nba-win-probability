library(rjson)
library(sqldf)

# Input:    Game ID (ex. '0021300359')
# Output:   Data frame with play-by-play breakdown
#           date, gameID, status, code, homeTeamID, awayTeamID, nationalTV
playByPlay <- function(gameID) {
  
  # Create URL and scrape the JSON for the input game
  url1 <- 'http://stats.nba.com/stats/playbyplay?GameID='  # JSON feed from NBA.com
  url2 <- '&StartPeriod=0&EndPeriod=0'                # Inputs include start and end (not used)
  url <- paste(url1, gameID, url2, sep = '')
  json <- fromJSON(file=url)[[3]]                     # (3) contains the actual info for the game
  
  # Check if plays exist for the given game
  temp <- json[[1]]                                   # (1) contains play by play data
  plays <- temp[[3]]                                  # (3) contains the actual rows
  
  if (length(plays) > 0) {
    
    # Create raw data frame
    plays <- lapply(plays, lapply, function(x) ifelse(is.null(x), NA, x))   # Convert nulls to NAs
    plays <- data.frame(matrix(unlist(plays), nrow = length(plays), byrow = TRUE)) # Turn list to data frame
    
    # Clean data frame
    plays <- plays[, -2]                        # Drop useless columns
    colnames(plays) <- c('gameID', 'action', 'detail', 'quarter', 'timeReal', 'timeGame',
                         'actionHome', 'actionNeutral', 'actionAway', 'score', 'margin')

    # Convert columns to proper types
    factors <- sapply(plays, is.factor)
    plays[factors] <- lapply(plays[factors], as.character)
    plays[, c('action', 'detail', 'quarter')] <- lapply(plays[, c('action', 'detail', 'quarter')], as.numeric)
    
    return(plays)
  }
}

# Input:    None
# Output:   Data frame of games from database
readGames <- function() {
  # Initialize database connection
  con <- dbConnect(drv = SQLite(), dbname = "nba_data.db")
  
  games <- dbReadTable(con, 'games')
  return(games)
}

# Input:    Data frame of games
# Output:   None -- database updated with plays
insertPlays <- function(games) {
  # Initialize database connection and make table
  con <- dbConnect(drv = SQLite(), dbname = "nba_data.db")
  dbSendQuery(conn = con,
              "CREATE TABLE IF NOT EXISTS actions(
              date VARCHAR(255) NOT NULL, 
              gameID VARCHAR(255) NOT NULL, 
              status VARCHAR(255), 
              homeTeamID BIGINT UNSIGNED NOT NULL, 
              awayTeamID BIGINT UNSIGNED NOT NULL, 
              nationalTV VARCHAR(255)
              );")
  
  # Insert all plays
  for (row in 1:nrow(games)) {
    gameID <- games[row, 'gameID']
    plays <- playByPlay(gameID)
    if (length(plays) > 0) {
      dbWriteTable(con, name = 'playsRaw', value = plays, row.names = 0, append = TRUE)
    }
    cat(row, ' / ', nrow(games), ' (', row / nrow(games) * 100, '%)\n')
  }
}