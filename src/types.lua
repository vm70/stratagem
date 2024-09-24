---@class (strict) Coords
---@field x integer
---@field y integer

---@class (strict) HighScore
---@field initials string
---@field score integer

---@class (strict) MatchInfo
---@field move_score integer
---@field x integer
---@field y integer
---@field gem_type integer
---@field match_list Coords[]

---@class Player
---@field grid_cursor Coords
---@field score integer
---@field init_level_score integer
---@field level_threshold integer
---@field level integer
---@field chances integer
---@field combo integer
---@field last_match MatchInfo
---@field letter_ids integer[]
---@field placement integer | nil
---@field score_cursor ScorePositions | integer
---@field swapping_gem Coords

---@class Particle
---@field coord Coords
---@field r number
---@field theta number
---@field vr number
---@field ar number

---@alias Version {major: integer, minor: integer, patch: integer} # semantic version number
