library(mailR)
source('DBInterface.r')
source('MineGames.r')
source('MineActions.r')
source('GetProbability.r')

games <- gamesDay('2014-04-25')
gameID <- games[1, 'gameID']
actions <- playByPlay(gameID)

send <- 'ccagrawal@gmail.com'
recip <- c('4084396844@txt.att.net')
subj <- paste('Update - ', format(Sys.time(), '%I:%M %p'), sep = '')
bod <- paste('HOU @ POR\n',
              'Quarter: 1\n',
              'Time Left: 3:23\n',
              'Score: 18-22\n',
              'Possession: Rockets\n',
              'Win Probability: 48.5%',
              'Expected Outcome: Win by 6',
              sep = '')

email <- send.mail(from = send,
                   to = recip,
                   subject = subj,
                   body = bod,
                   smtp = list(host.name = "smtp.gmail.com", 
                               port = 465, 
                               user.name = "ccagrawal", 
                               passwd = "aytyiekpnmjqfham", 
                               ssl = TRUE, 
                               tls = TRUE),
                   authenticate = TRUE,
                   send = TRUE)