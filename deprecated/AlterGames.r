# Scrapes final scores and adds it to the games table in the DB
# Should eventually be deprecated and incorporated into the read actions script

library(zoo)
source('DBInterface.r')

games <- readTable('games')

for (i in 1:nrow(games)) {
  gameID <- games[i, 'gameID']
  actions <- readActions(gameID)
  
  # Clean up margin (just in case, not sure if this is necessary)
  actions[1, 'margin'] <- 0
  actions[which(actions$margin == 'TIE'), 'margin'] <- 0
  actions$margin <- as.numeric(actions$margin)
  actions$margin <- na.locf(actions$margin, na.rm = FALSE)
  
  games[i, 'final'] <- actions[nrow(actions), 'margin']
  cat(i, ' / ', nrow(games), '\n', sep = '')
}

games[which(games$final == 0), 'final'] <- NA

sql <- "CREATE TABLE IF NOT EXISTS games2(
        date VARCHAR(255) NOT NULL, 
        ngameID VARCHAR(255) NOT NULL, 
        status VARCHAR(255), 
        homeTeamID BIGINT UNSIGNED NOT NULL, 
        awayTeamID BIGINT UNSIGNED NOT NULL, 
        nationalTV VARCHAR(255), 
        type VARCHAR(255) NOT NULL,
        final TINYINT,
        FOREIGN KEY(ngameID) REFERENCES games(gameID)
        );"
runQuery(sql)
writeTable('games2', games)

sql <- "ALTER TABLE games
        ADD COLUMN final TINYINT"
runQuery(sql)

sql <- "UPDATE games
        SET final = (
        SELECT final
        FROM games2
        WHERE ngameID = gameID);"
runQuery(sql)

sql <- "DROP TABLE games2"
runQuery(sql)