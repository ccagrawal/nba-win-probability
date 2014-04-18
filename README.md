# NBA Win Probability

The goal of this project is to create a website that shows live winning probabilities of ongoing games.

##### Listing Games

[NBA.com](http://www.nba.com/) is currently used to get a list of the games each day. [NBA.com](http://www.nba.com/) provides JSON feeds with game lists for each day since 1946 ([example](http://stats.nba.com/stats/scoreboard/?LeagueID=00&gameDate=12%2F02%2F2013&DayOffset=0)).

Code to collect the list of games in an input date range has been completed in R. The list includes the following information:
* Date
* Game ID (for further use with NBA.com)
* Status (final, cancelled, postponed)
* Home Team ID
* Away Team ID
* National TV

This information is stored in a sqlite database. Currently, I need to add a column to the database categorizing each game as preseason, regular season, or postseason.