plays$startPos <- 0
plays$endPos <- 0

plays$gameID <- NULL
plays$timeReal <- NULL

plays[unlist(lapply(plays$actionHome, function(x) grepl('Jump Ball', x))), 'startPos'] <- 1
plays[unlist(lapply(plays$actionAway, function(x) grepl('Jump Ball', x))), 'startPos'] <- 2

plays[which(plays$action == 1 & is.na(plays$actionHome)), 'endPos'] <- 2
plays[which(plays$action == 1 & is.na(plays$actionHome)), 'startPos'] <- 1

plays[which(plays$action == 1 & is.na(plays$actionAway)), 'endPos'] <- 1
plays[which(plays$action == 1 & is.na(plays$actionAway)), 'startPos'] <- 2