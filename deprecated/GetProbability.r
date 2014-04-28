# Put in inputs and get the output probability!

source('DBInterface.r')
source('CreateTimelines.r')

# Input:  Time elapsed (seconds), margin (team - opp), 
#         Possession (1 means team, -1 mean opp, omit for include all)
#         Type (regular season, all star game, postseason)
#         Home (1 means home, -1 means away)
# Output: Probability (ex. 0.20384)
getProbability <- function(period, rem, margin, possession = 2, type = 'regular season', home = 1) {
  
  time <- timeElapsed(period, rem)
  
  # If no possession was input, just do anybody's possession
  if (possession == 2) {
    sql <- paste("SELECT final
                  FROM timelines
                  WHERE time = ", time,
                 " AND (possession = 0 OR possession = -1 OR possession = 1)
                  AND margin =", margin * home,
                 " AND type = '", type,
                 "';", sep = '')
  } else {
    sql <- paste("SELECT final
                  FROM timelines
                  WHERE time = ", time,
                 " AND possession = ", possession * home,
                 " AND margin =", margin * home,
                 " AND type = '", type,
                 "';", sep = '')
  }
  
  results <- runQuery(sql)
  results$final <- results$final * home
  
  win <- length(results[which(results$final > 0), ])
  count <- nrow(results)
  prob <- win / count
  pred <- mean(results$final)
  
  return(list(prob, pred))
}