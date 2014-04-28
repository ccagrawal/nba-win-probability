# Scrapes game information from NBA and Basketball Reference and add it to the database

library(rjson)
library(RCurl)
library(XML)
source('DBInterface.r')

# Input:    Date (ex. '2013-11-23')
# Output:   Data frame with info for games that day
#           date, gameID, status, homeTeamID, awayTeamID, nationalTV
gamesDay <- function(rawDate) {
  
  # Create NBA URL and scrape the JSON for the input day
  rawDate <- as.Date(rawDate)                         # Clean date input
  urlNBA1 <- 'http://stats.nba.com/stats/scoreboard/?LeagueID=00&gameDate='  # JSON feed from NBA.com
  urlNBA2 <- '&DayOffset=0'                           # Inputs include date and offset (not used)
  date <- format(rawDate, format = '%m%%2F%d%%2F%Y')  # Format date to be used in URL "mm%2Fdd%2FYYYY"
  urlNBA <- paste(urlNBA1, date, urlNBA2, sep = '')
  json <- fromJSON(file=urlNBA)[[3]]                  # (3) contains the actual info for the day
  
  # Check if games exist for the given day
  temp <- json[[1]]                                   # (1) contains game list info
  gameList <- temp[[3]]                               # (3) contains the actual rows
  
  if (length(gameList) > 0) {
    
    # Create raw data frame
    gameList <- lapply(gameList, lapply, function(x) ifelse(is.null(x), NA, x))   # Convert nulls to NAs
    gameList <- data.frame(matrix(unlist(gameList), nrow = length(gameList), byrow = TRUE)) # Turn list to data frame
    
    # Clean data frame
    gameList <- gameList[, c(1, 3, 5, 7, 8, 12)]      # Drop useless columns
    colnames(gameList) <- c('date', 'gameID', 'status', 'homeTeamID', 'awayTeamID', 'nationalTV')
    gameList$date <- as.character(rawDate)            # Store as character because sqlite doesn't deal with dates
    
    # Convert factors to characters (don't use numeric on gameID because it chops leading 0s!)
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

# Input:    Games data frame, year (1996 means 1996-97 season)
# Output:   Games data frame with proper type
addType <- function(games, year) {
  
  games$type <- 'preseason'             # By default, label every game as preseason

  # Create url templates for basketball reference
  urlBRef1 <- 'http://www.basketball-reference.com/leagues/NBA_'
  urlBRef2 <- '_games.html'
  urlBRef <- paste(urlBRef1, year + 1, urlBRef2, sep = "")
  
  # Scrape tables
  tables <- readHTMLTable(urlBRef)
  
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
  
  # Change type of All Star games
  games[which(games$homeTeamID == 1610616834), 'type'] <- 'all star game'
  games[which(games$awayTeamID == 1610616834), 'type'] <- 'all star game'
    
  return(games)
}

# Input:    Start Year, End Year (ex. 1996 means 1996-97 season)
# Output:   None -- database modified
insertGames <- function(startYear, endYear) {
  
  # Create table in database (won't do anything if table already exists)
  createGames()
  
  # Scrape games year by year
  for (year in startYear:endYear) {
    time <- Sys.time()
    
    # Get game info from NBA.com
    start <- paste(year, '-08-02', sep = '')
    end <- paste(year + 1, '-08-01', sep = '')
    games <- gamesRange(start, end)
    
    # Add type from Basketball Reference
    games <- addType(games, year)
    
    # Make backup and add games to database
    file.copy('nba_data.db', 'backup_nba_data.db', overwrite = TRUE)
    writeTable('games', games)
    
    # Heartbeat with time
    cat(Sys.time() - time, '\n', sep = '')
  }
}