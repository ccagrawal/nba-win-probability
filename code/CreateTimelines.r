# Converts actions into timeline and adds it to DB

library(zoo)
source('DBInterface.r')

# Input:   Actions data frame
# Output:  Timeline data frame
convertActions <- function(actions) {
  
  # Filter actions to take out non-checkpoints
  filtered <- filterActions(actions)
  
  # Calculate room for a timeline
  numOT <- actions[nrow(actions), 'quarter'] - 4
  numSeconds <- (48 + 5 * numOT) * 60
  
  # Allocate room in timeline for each second
  timeline <- as.data.frame(matrix(data = 0, nrow = numSeconds, ncol = 4))
  colnames(timeline) <- c('time', 'possession', 'checkpoint', 'margin')
  timeline$time <- seq(from = 0, to = numSeconds - 1, by = 1)
  
  # Make margin NA so we can do the neat NA fill trick
  timeline$margin <- NA
  timeline[1, 'margin'] <- 0
  
  # Create checkpoints at the start of each period
  timeline[seq(from = 1, to = 2880, by = 720), 'checkpoint'] <- 1
  if (numOT > 0) {
    timeline[seq(from = 2881, to = numSeconds, by = 300), 'checkpoint'] <- 1
  }
  
  # Create time markers
  rowBefore <- 1
  rowAfter <- nextCheckpoint(timeline, 1)
  
  for (i in 1:nrow(filtered)) {
    
    row <- filtered[i, 'time'] + 1            # Seconds start from 0, rows start from 1
    possBefore <- filtered[i, 'possBefore']
    possAfter <- filtered[i, 'possAfter']
    
    # Deal with corner cases separately
    if (row > 1 && row <= nrow(timeline)) { # Middle of game
      
      # If current row is at the after checkpoint, find the next checkpoint
      if (row > rowAfter) {
        rowAfter <- nextCheckpoint(timeline, row)
      }
      
      # If current row already has a checkpoint, don't worry about the possBefore
      if (timeline[row, 'checkpoint'] == 1) {
        possBefore <- 0                     # When possBefore is 0, it doesn't do shit
      } else {
        timeline[row, 'checkpoint'] <- 1    # Add the checkpoint if it isn't there
      }
      
      # If no possession is marked before, mark it
      # Else if possession before is different from what action says, error
      if (timeline[row - 1, 'possession'] == 0) {
        timeline[rowBefore:(row - 1), 'possession'] <- possBefore
      } else if ((timeline[row - 1, 'possession'] != possBefore) && (possBefore != 0)) {
        timeline[rowBefore:(row - 1), 'possession'] <- 0
      }
      
      # Mark possession after
      timeline[row:(rowAfter - 1), 'possession'] <- possAfter
      
      # Fill in margin
      timeline[row, 'margin'] <- filtered[i, 'margin']
      
    } else if (row == 1) {    # Game start
      
      # Mark possession after
      timeline[row:(rowAfter - 1), 'possession'] <- possAfter
      
    } else {                  # Game end
      
      # If no possession is marked before, mark it
      # Else if possession before is different from what action says, error
      if (timeline[row - 1, 'possession'] == 0) {
        timeline[rowBefore:(row - 1), 'possession'] <- possBefore
      } else if ((timeline[row - 1, 'possession'] != possBefore) && (possBefore != 0)) {
        errors <- c(errors, row)
      }
      
    }
    
    # Shift rowBefore
    rowBefore <- row
  }
  
  # Fill down margin
  timeline$margin <- na.locf(timeline$margin, na.rm = FALSE)
  
  return(timeline)
}

# Input:   Actions data frame from the database
# Output:  Filtered actions data frame
filterActions <- function(actions) {
  
  # Clean up margin in actions
  actions[1, 'margin'] <- 0
  actions[which(actions$margin == 'TIE'), 'margin'] <- 0
  actions$margin <- as.numeric(actions$margin)
  actions$margin <- na.locf(actions$margin, na.rm = FALSE)
  
  # Read instructions
  instructions <- readTable('instructions')
  
  # Make space for the "cleaned" actions
  filtered <- as.data.frame(matrix(data = -1, nrow = nrow(actions), ncol = 4))
  colnames(filtered) <- c('time', 'possBefore', 'possAfter', 'margin')
  
  # Iterate through each action
  for (i in 1:nrow(actions)) {
    
    # Find action in the instructions table
    row <- which((instructions$action == actions[i, 'action']) & (instructions$detail == actions[i, 'detail']))
    
    # Only filter the action if it is a checkpoint
    if (instructions[row, 'checkpoint'] == 1) {
      
      # Factor tells us if the action was for the home or away team (1 = home)
      factor <- 1
      if (grepl(instructions[row, 'lookup'], actions[i, 'actionHome'], ignore.case = TRUE) == 0) {
        factor <- -1
      }
      
      filtered[i, 'time'] <- timeElapsed(actions[i, 'quarter'], actions[i, 'time'])
      filtered[i, 'possBefore'] <- instructions[row, 'before'] * factor
      filtered[i, 'possAfter'] <- instructions[row, 'after'] * factor
      filtered[i, 'margin'] <- actions[i, 'margin']
    }
  }
  
  # Remove all the spaces for actions which weren't checkpoints
  filtered <- filtered[-which(filtered$time == -1), ]
  
  return(filtered)
}

# Input:   Timeline, current row
# Output:  The first row with a checkpoint after the current row
nextCheckpoint <- function(timeline, row) {
  i <- row + 1
  while (i <= nrow(timeline)) {
    if (timeline[i, 'checkpoint'] == 1) {
      return(i)     # Return the row number once a checkpoint has been found
    }
    
    i <- i + 1
  }
  
  return(nrow(timeline))    # If there are no more checkpoints, return the last row
}

# Input:   Period (or quarter / OT), time remaining (ex. 10:43)
# Output:  Seconds elapsed
timeElapsed <- function(period, rem) {
  
  # Convert time remaining into seconds
  remMin <- lapply(strsplit(rem, ":"), as.numeric)[[1]][1]
  remSec <- lapply(strsplit(rem, ":"), as.numeric)[[1]][2]
  rem <- remMin * 60 + remSec
  
  if (period <= 4) {                # If not in OT yet
    return(720 * period - rem)      # 720 seconds per quarter
  } else {
    return(2880 + 300 * (period - 4) - rem)   # 2880 seconds in 4 quarters, 300 seconds per OT
  }
}

# Input:   Games data frame
# Output:  Nothing -- database updated with timelines
insertTimelines(games) {
  
  # Create table in database (won't do anything if table already exists)
  createTimelines()
  
  # Insert all actions
  for (row in 1:nrow(games)) {
    gameID <- games[row, 'gameID']
    plays <- playByPlay(gameID)
    
    # Only insert if plays were available (duh)
    if (length(plays) > 0) {
      writeTable('actions', plays)
    }
    
    # Backup every 50 games
    if (row %% 50 == 0) {
      file.copy('nba_data.db', 'backup_nba_data.db', overwrite = TRUE)
    }
    
    # Heartbeat
    cat(row, ' / ', nrow(games), ' (', row / nrow(games) * 100, '%)\n', sep = '')
  }
}