# Scrapes action information from NBA and adds it to the database

library(rjson)
source('DBInterface.r')

# Input:    Game ID (ex. '0021300359')
# Output:   Data frame with play-by-play breakdown
#           date, gameID, status, code, homeTeamID, awayTeamID, nationalTV
playByPlay <- function(gameID) {
  
  # Create URL and scrape the JSON for the input game
  urlNBA1 <- 'http://stats.nba.com/stats/playbyplay?GameID='  # JSON feed from NBA.com
  urlNBA2 <- '&StartPeriod=0&EndPeriod=0'                 # Inputs include start and end (not used)
  urlNBA <- paste(urlNBA1, gameID, urlNBA2, sep = '')
  json <- fromJSON(file=urlNBA)[[3]]                      # (3) contains the actual info for the game
  
  # Check if plays exist for the given game
  temp <- json[[1]]                                       # (1) contains play by play data
  plays <- temp[[3]]                                      # (3) contains the actual rows
  
  if (length(plays) > 0) {
    
    # Create raw data frame
    plays <- lapply(plays, lapply, function(x) ifelse(is.null(x), NA, x))   # Convert nulls to NAs
    plays <- data.frame(matrix(unlist(plays), nrow = length(plays), byrow = TRUE)) # Turn list to data frame
    
    # Clean data frame
    plays <- plays[, -c(2, 6)]                        # Drop useless columns
    colnames(plays) <- c('gameID', 'action', 'detail', 'quarter', 'time',
                         'actionHome', 'actionNeutral', 'actionAway', 'score', 'margin')

    # Convert columns to proper types
    factors <- sapply(plays, is.factor)
    plays[factors] <- lapply(plays[factors], as.character)
    plays[, c('action', 'detail', 'quarter')] <- lapply(plays[, c('action', 'detail', 'quarter')], as.numeric)
    
    return(plays)
  }
}

# Input:    Data frame of games
# Output:   None -- database updated with plays
insertPlays <- function(games) {
  
  # Create table in database (won't do anything if table already exists)
  createActions()
  
  # Insert all actions
  for (row in 1:nrow(games)) {
    gameID <- games[row, 'gameID']
    plays <- playByPlay(gameID)
    
    # Only insert if plays were available (duh)
    if (length(plays) > 0) {
      writeTable('actions', plays)
    }
    
    # Backup every 50 games
    if (row %% 50 == 0) {
      file.copy('nba_data.db', 'backup_nba_data.db', overwrite = TRUE)
    }
    
    # Heartbeat
    cat(row, ' / ', nrow(games), ' (', row / nrow(games) * 100, '%)\n', sep = '')
  }
}