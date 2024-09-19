---@alias Coords {x: integer, y: integer}
---@alias HighScore {initials: string, score: integer}
---@alias Match {move_score: integer, x: integer, y: integer, color: integer}
---@alias Player {grid_cursor: Coords, score: integer, init_level_score: integer, level_threshold: integer, level: integer, chances: integer, combo: integer, last_match: Match, letter_ids: integer[], placement: integer | nil, score_cursor: ScorePositions}
