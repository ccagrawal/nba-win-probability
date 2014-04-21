library(sqldf)

# Initialize database connection and make instructions table
con <- dbConnect(drv = SQLite(), dbname = "nba_data.db")
dbSendQuery(conn = con,
            "CREATE TABLE IF NOT EXISTS instructions(
            action INT UNSIGNED, 
            detail INT UNSIGNED, 
            pattern VARCHAR(255), 
            lookup VARCHAR(255), 
            before TINYINT,
            after TINYINT,
            checkpoint TINYINT
            );")

# Import instructions and add into the db
instructions <- read.csv('../exports/uniqueActions.csv', stringsAsFactors = FALSE)
dbWriteTable(con, name = 'instructions', value = instructions, row.names = 0, append = TRUE)

# Read instructions table (for testing purpose)
instructions <- dbReadTable(con, name = 'instructions')