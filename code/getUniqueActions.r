library(sqldf)
require(Rlibstree)

# Initialize database connection
con <- dbConnect(drv = SQLite(), dbname = "nba_data.db")

# Get unique combinations of action and detail
unique <- sqldf("SELECT action, detail
                FROM actions 
                GROUP BY action, detail;",
                dbname = "nba_data.db")

# Create columns to store the common pattern and count of actions
unique$pattern <- ""
unique$count <- 0


# Loop through each combination of action / detail and find the common substring
for (i in 1:nrow(unique)) {
  
  # Load 100 actions of that action / detail
  sample <- sqldf(paste("SELECT actionHome, actionNeutral, actionAway 
                        FROM actions
                        WHERE action=", unique[i, 'action'],
                        " AND detail=", unique[i, 'detail'], 
                        ' LIMIT 100;', sep = ''), dbname = 'nba_data.db')
  
  # Export sample to be analyzed for creating the instructions
  write.csv(sample, paste('../exports/', unique[i, 'action'], '-', unique[i, 'detail'], '.csv', sep = ''), row.names = FALSE)
  
  # We don't know if the action is from the home team, neutral, or away team, so merge them all
  sample$merge <- paste(sample$actionHome, sample$actionNeutral, sample$actionAway, sep = '\t')
  
  # Find the pattern and place it in the unique df
  unique[i, 'pattern'] <- getLongestCommonSubstring(sample$merge)[1]
  
  # Heartbeat
  cat(i, ' / ', nrow(unique), '\t\t', unique[i, 'action'], '\t', 
      unique[i, 'detail'], '\t', unique[i, 'pattern'], '\n', sep = '')
}

# Loop through each combination of action / detail and find the number or examples
for (i in 1:nrow(unique)) {
  
  # Load counts of that action / detail
  unique[i, 'count'] <- sqldf(paste("SELECT COUNT(*) 
                                    FROM actions
                                    WHERE action=", unique[i, 'action'],
                                    " AND detail=", unique[i, 'detail'], 
                                    ';', sep = ''), dbname = 'nba_data.db')[1, 1]
  
  # Heartbeat
  cat(i, ' / ', nrow(unique), '\t\t', unique[i, 'action'], '\t', 
      unique[i, 'detail'], '\t', unique[i, 'count'], '\n', sep = '')
}

# Clean up patterns before exporting unique actions/details with patterns and counts
unique$pattern <- gsub('\\(.*', '', unique$pattern)
unique$pattern <- gsub("'", '', unique$pattern)
unique$pattern <- gsub('NA', '', unique$pattern)
unique$pattern <- gsub('\t', '', unique$pattern)
unique$pattern <- gsub('^\\s+|\\s+$', '', unique$pattern)
write.csv(unique, '../exports/uniqueActions.csv', row.names = FALSE)

# Load samples for analysis
sample <- sqldf("SELECT gameID, actionHome, actionNeutral, actionAway 
                FROM actions
                WHERE action=11;", dbname = 'nba_data.db')

sample$home.test <- grepl('Ejection', sample$actionHome, ignore.case = TRUE)
sample$neut.test <- grepl('Ejection', sample$actionNeutral, ignore.case = TRUE)
sample$away.test <- grepl('Ejection', sample$actionAway, ignore.case = TRUE)
sample$count <- rowSums(sample[, c('home.test', 'neut.test', 'away.test')])
sample <- sample[which(sample$count == 0), ]
