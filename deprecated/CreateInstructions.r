# Exports unique actions; imports csv and makes instruction table
# Since this requires manual work in Excel, it's not object-oriented

require(Rlibstree)
source('DBInterface.r')

# Get unique combinations of action and detail
unique <- runQuery("SELECT action, detail
                    FROM actions 
                    GROUP BY action, detail;")

# Create columns to store the common pattern and count of actions
unique$pattern <- ""
unique$count <- 0

# Loop through each combination of action / detail and find the common substring
for (i in 1:nrow(unique)) {
  
  # Load 100 actions of that action / detail
  sample <- runQuery(paste("SELECT actionHome, actionNeutral, actionAway 
                            FROM actions
                            WHERE action=", unique[i, 'action'],
                            " AND detail=", unique[i, 'detail'], 
                            ' LIMIT 100;', sep = ''))
  
  # Load counts of that action / detail
  unique[i, 'count'] <- runQuery(paste("SELECT COUNT(*) 
                                        FROM actions
                                        WHERE action=", unique[i, 'action'],
                                       " AND detail=", unique[i, 'detail'], 
                                       ';', sep = ''))[1, 1]
  
  # Export sample to be analyzed for creating the instructions
  write.csv(sample, paste('../exports/', unique[i, 'action'], '-', unique[i, 'detail'], '.csv', sep = ''), row.names = FALSE)
  
  # We don't know if the action is from the home team, neutral, or away team, so merge them all
  sample$merge <- paste(sample$actionHome, sample$actionNeutral, sample$actionAway, sep = '\t')
  
  # Find the pattern and place it in the unique df
  unique[i, 'pattern'] <- getLongestCommonSubstring(sample$merge)[1]
  
  # Heartbeat
  cat(i, ' / ', nrow(unique), '\t\t', unique[i, 'action'], '\t', unique[i, 'detail'], '\n', sep = '')
}

# Clean up patterns before exporting unique actions/details with patterns and counts
unique$pattern <- gsub('\\(.*', '', unique$pattern)
unique$pattern <- gsub("'", '', unique$pattern)
unique$pattern <- gsub('NA', '', unique$pattern)
unique$pattern <- gsub('\t', '', unique$pattern)
unique$pattern <- gsub('^\\s+|\\s+$', '', unique$pattern)
write.csv(unique, '../exports/uniqueActions.csv', row.names = FALSE)


# Load samples for analysis
sample <- runQuery("SELECT gameID, actionHome, actionNeutral, actionAway 
                    FROM actions
                    WHERE action=11;")

# Count the number of instances for the word in each column, make sure sum is at most 1
sample$home.test <- grepl('Ejection', sample$actionHome, ignore.case = TRUE)
sample$neut.test <- grepl('Ejection', sample$actionNeutral, ignore.case = TRUE)
sample$away.test <- grepl('Ejection', sample$actionAway, ignore.case = TRUE)
sample$count <- rowSums(sample[, c('home.test', 'neut.test', 'away.test')])
sample <- sample[which(sample$count == 0), ]


# Create table (does nothing if it already exists)
createInstructions()

# Import instructions and add into the db
instructions <- read.csv('../exports/uniqueActions.csv', stringsAsFactors = FALSE)
writeTable('instructions', instructions)