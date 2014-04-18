library(RCurl)
library(XML)

# Initialize database connection
con <- dbConnect(drv = SQLite(), dbname = "nba_data.db")
games <- dbReadTable(con, 'games')

# Create base url
url.1 <- 'http://www.basketball-reference.com/leagues/NBA_'
url.2 <- '_games.html'

year <- 2013

# Create schedule url
url <- paste(url.1, year, url.2, sep = "")

# Scrape tables and get number of rows in each table
tables <- readHTMLTable(url)
n.rows <- unlist(lapply(tables, function(t) dim(t)[1]))

df <- data.frame(tables['games'])
df <- data.frame(lapply(df, as.character), stringsAsFactors = FALSE)

regular.start <- as.Date(df[1, 1], format = '%a, %b %d, %Y')
regular.end <- as.Date(df[nrow(df), 1], format = '%a, %b %d, %Y')

df <- data.frame(tables['games_playoffs'])
df <- data.frame(lapply(df, as.character), stringsAsFactors = FALSE)

post.start <- as.Date(df[1, 1], format = '%a, %b %d, %Y')
post.end <- as.Date(df[nrow(df), 1], format = '%a, %b %d, %Y')

