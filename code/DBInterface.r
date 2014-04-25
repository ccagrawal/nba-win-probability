# "Black box" for reading from and writing to the database

library(RSQLite)

createGames <- function(dbName = 'nba_data.db') {
  sql <- "CREATE TABLE IF NOT EXISTS games(
          date VARCHAR(255) NOT NULL, 
          gameID VARCHAR(255) NOT NULL PRIMARY KEY, 
          status VARCHAR(255), 
          homeTeamID BIGINT UNSIGNED NOT NULL, 
          awayTeamID BIGINT UNSIGNED NOT NULL, 
          nationalTV VARCHAR(255), 
          type VARCHAR(255) NOT NULL
          )"
  runQuery(sql, dbName)
}

createActions <- function(dbName = 'nba_data.db') {
  sql <- "CREATE TABLE IF NOT EXISTS actions(
          gameID VARCHAR(255) NOT NULL, 
          action INT UNSIGNED, 
          detail INT UNSIGNED, 
          quarter INT UNSIGNED, 
          time VARCHAR(255), 
          actionHome VARCHAR(255), 
          actionNeutral VARCHAR(255), 
          actionAway VARCHAR(255), 
          score VARCHAR(255), 
          margin VARCHAR(255),
          FOREIGN KEY(gameID) REFERENCES games(gameID)
          );"
  runQuery(sql, dbName)
}

createInstructions <- function(dbName = 'nba_data.db') {
  sql <- "CREATE TABLE IF NOT EXISTS instructions(
          action INT UNSIGNED, 
          detail INT UNSIGNED, 
          pattern VARCHAR(255), 
          lookup VARCHAR(255), 
          before TINYINT,
          after TINYINT,
          checkpoint TINYINT
          );"
  runQuery(sql, dbName)
}

createTimelines <- function(dbName = 'nba_data.db') {
  sql <- "CREATE TABLE IF NOT EXISTS timelines(
          gameID VARCHAR(255) NOT NULL,
          time INT UNSIGNED, 
          possession TINYINT,  
          margin TINYINT, 
          FOREIGN KEY(gameID) REFERENCES games(gameID)
          );"
  runQuery(sql, dbName)
}

readActions <- function(gameID) {
  actions <- runQuery(paste('SELECT * ',
                            'FROM actions ',
                            'WHERE gameID = \'', gameID, 
                            '\';', sep = ''))
  return(actions)
}

writeTable <- function(table, data, dbName = 'nba_data.db') {
  connect <- dbConnect(drv = SQLite(), dbname = dbName)
  dbWriteTable(connect, name = table, value = data, row.names = 0, append = TRUE)
  closeConnection(connect)
}

readTable <- function(table, dbName = 'nba_data.db') {
  connect <- dbConnect(drv = SQLite(), dbname = dbName)
  results <- dbReadTable(connect, name = table)
  closeConnection(connect)
  return(results)
}

removeTable <- function(table, dbName = 'nba_data.db') {
  connect <- dbConnect(drv = SQLite(), dbname = dbName)
  dbRemoveTable(connect, name = table)
  closeConnection(connect)
}

listTables <- function(dbName = 'nba_data.db') {
  connect <- dbConnect(drv = SQLite(), dbname = dbName)
  print(dbListTables(connect))
  closeConnection(connect)
}

listFields <- function(table, dbName = 'nba_data.db') {
  connect <- dbConnect(drv = SQLite(), dbname = dbName)
  print(dbListFields(connect, name = table))
  closeConnection(connect)
}

runQuery <- function(sql, dbName = 'nba_data.db') {
  connect <- dbConnect(drv = SQLite(), dbname = dbName)
  result <- tryCatch(dbGetQuery(connect, sql), finally = closeConnection(connect))
  return(result)
}

closeConnection <- function(connect) {
  sqliteCloseConnection(connect)
  sqliteCloseDriver(SQLite())
}