# Merges timeline and game to make a super timeline
# Should eventually be deprecated and incorporated into the create timelines script

source('DBInterface.r')

sql <- "ALTER TABLE timelines
        ADD COLUMN type VARCHAR(255)"
runQuery(sql)

sql <- "ALTER TABLE timelines
        ADD COLUMN final TINYINT"
runQuery(sql)

sql <- "UPDATE timelines
        SET type = (
        SELECT type
        FROM games
        WHERE games.gameID = timelines.gameID);"
runQuery(sql)

sql <- "UPDATE timelines
        SET final = (
        SELECT final
        FROM games
        WHERE games.gameID = timelines.gameID);"
runQuery(sql)