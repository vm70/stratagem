---@class (strict) Coords # coordinate pair, used for defining places in the grid.
---@field x integer # x-value (column number in grid)
---@field y integer # y-value (row number in grid)

---@class (strict) HighScore # a high score in the leaderboard.
---@field initials string # three characters representing the player's initials
---@field score integer # the player's score at the end of a game

---@class (strict) MatchInfo # information about a match in the game.
---@field move_score integer # the match's total point score
---@field x integer # grid x-coordinate of the match's top-left gem
---@field y integer # grid y-coordinate of the match's top-left gem
---@field gem_type integer # which gem type it is (1 to 8)
---@field match_list Coords[] # list of gem coordinates belonging to the match

---@class Player # table containing all player information.
---@field grid_cursor Coords | nil # position of the player's cursor
---@field score integer # player's current score
---@field init_level_score integer # player's score at the start of the level
---@field level_threshold integer # player's target score to get to the next level
---@field level integer # player's current level
---@field chances integer # how many chances left the player has for making wrong moves
---@field combo integer # player's current combo (how many matches have been made since the player swapped two gems)
---@field last_match MatchInfo | nil # player's last match
---@field letter_ids integer[] # player's initials for entering a high score
---@field placement integer | nil # player's placement on the leaderboard
---@field score_cursor ScorePositions # cursor position for entering high score initials
---@field swapping_gem Coords | nil # gem coordinate the player will swap the cursor with

---@class Particle # a particle used for match animations
---@field coord Coords # center gem coordinate, used to determine the particle's relative origin
---@field theta number # angle [rotations] from the particle's relative origin

---@alias Version {major: integer, minor: integer, patch: integer} # semantic version number
