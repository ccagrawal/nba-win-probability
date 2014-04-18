library(rjson)
library(sqldf)

# Input:    Date (ex. '2013-11-23')
# Output:   Data frame with info for games that day
#           date, gameID, status, homeTeamID, awayTeamID, nationalTV
gamesDay <- function(rawDate) {
  
  # Create URL and scrape the JSON for the input day
  rawDate <- as.Date(rawDate)                         # Clean date input
  url1 <- 'http://stats.nba.com/stats/scoreboard/?LeagueID=00&gameDate='  # JSON feed from NBA.com
  url2 <- '&DayOffset=0'                              # Inputs include date and offset (not used)
  date <- format(rawDate, format = '%m%%2F%d%%2F%Y')  # Format date to be used in URL "mm%2Fdd%2FYYYY"
  url <- paste(url1, date, url2, sep = '')
  json <- fromJSON(file=url)[[3]]                     # (3) contains the actual info for the day
  
  # Check if games exist for the given day
  temp <- json[[1]]                                   # (1) contains game list info
  gameList <- temp[[3]]                               # (3) contains the actual rows
  
  if (length(gameList) > 0) {
    
    # Create raw data frame
    gameList <- lapply(gameList, lapply, function(x) ifelse(is.null(x), NA, x))   # Convert nulls to NAs
    gameList <- data.frame(matrix(unlist(gameList), nrow = length(gameList), byrow = TRUE)) # Turn list to data frame
    
    # Clean data frame
    gameList <- gameList[, c(1, 3, 5, 7, 8, 12)]   # Drop useless columns
    colnames(gameList) <- c('date', 'gameID', 'status', 'homeTeamID', 'awayTeamID', 'nationalTV')
    gameList$date <- as.character(rawDate)            # Store as character because sqlite doesn't deal with dates
    
    # Convert factors to characters (don't use numeric because it chops leading 0s!)
    factors <- sapply(gameList, is.factor)
    gameList[factors] <- lapply(gameList[factors], as.character)
    gameList[, "homeTeamID"] <- as.numeric(gameList[, "homeTeamID"])
    gameList[, "awayTeamID"] <- as.numeric(gameList[, "awayTeamID"])
    
    return(gameList)
  }
}

# Input:    Start Date, End Date (ex. '2013-11-23')
# Output:   Data frame with info for games in that range
#           date, gameID, status, code, homeTeamID, awayTeamID, nationalTV
gamesRange <- function(rawDate1, rawDate2) {
  
  allGames <- data.frame()                            # Create empty data frame

  # Iterate through days and add games to allGames data frame 
  for (date in seq(from = as.Date(rawDate1), to = as.Date(rawDate2), by = 1)) {
    date <- as.Date(date, origin = '1970-01-01')      # Convert epoch (days) to date object
    
    # Keep trying to grab data if an error comes
    errCount <- 0
    repeat {
      tempGames <- tryCatch(gamesDay(date), error = function(e) e)
      
      if (!inherits(tempGames, "error")) {
        break                                         # Break when we don't get an error
      }
      
      errCount <- errCount + 1
      cat('Error ', errCount, '\n')
    }
    
    # Print date and add games onto allGames data frame
    cat(format(date), '\n')
    allGames <- rbind(allGames, tempGames)
  }
  
  return(allGames)
}

# Input:    Start Year, End Year (ex. 1996)
# Output:   None -- database modified
insertGames <- function(startYear, endYear) {
  # Initialize database connection and make table
  con <- dbConnect(drv = SQLite(), dbname = "nba_data.db")
  dbSendQuery(conn = con,
              "CREATE TABLE IF NOT EXISTS games(
              date VARCHAR(255) NOT NULL, 
              gameID VARCHAR(255) NOT NULL PRIMARY KEY, 
              status VARCHAR(255), 
              homeTeamID BIGINT UNSIGNED NOT NULL, 
              awayTeamID BIGINT UNSIGNED NOT NULL, 
              nationalTV VARCHAR(255)
              )")
  
  # Insert all historic games
  for (year in startYear:endYear) {
    time <- Sys.time()
    start <- paste(year, '-08-02', sep = '')
    end <- paste(year + 1, '-08-01', sep = '')
    games <- gamesRange(start, end)
    file.copy('nba_data.db', 'backup_nba_data.db', overwrite = TRUE)
    dbWriteTable(con, name = 'games', value = games, row.names = 0, append = TRUE)
    cat(Sys.time() - time, '\n', sep = '')
  }
}