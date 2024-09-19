-- stratagem v0.3.0
-- by vincent "vm" mercator & co.

--# selene: allow(undefined_variable)

VERSION = {
	major = 0,
	minor = 3,
	patch = 0,
}

---@enum States
STATES = {
	title_screen = 1,
	credits = 2,
	game_init = 3,
	generate_grid = 4,
	game_idle = 5,
	swap_select = 6,
	player_matching = 7,
	show_match_points = 8,
	fill_grid = 9,
	combo_check = 10,
	level_up = 11,
	game_over = 12,
	enter_high_score = 13,
	high_scores = 14,
}

---@enum ScorePositions
SCORE_POSITIONS = {
	first = 1,
	second = 2,
	third = 3,
	ok = 4,
}

---@type integer[] List of level music starting positions
LEVEL_MUSIC = { 2, 8 }

---@type integer Number of gems in the game (max 8)
N_GEMS = 8

---@type integer Number of frames to wait before dropping new gems down
DROP_FRAMES = 2

---@type integer Number of frames to wait to show the match points
MATCH_FRAMES = 20

---@type integer[] main PICO-8 colors of gems
GEM_COLORS = { 8, 9, 12, 11, 14, 7, 4, 13 }

---@type integer How many points a three-gem match scores on level 1
BASE_MATCH_PTS = 3

---@type integer How many three-gem matches without combos should get you to level 2
L1_MATCHES = 50

---@type integer How many points needed to get to level 2
L1_THRESHOLD = L1_MATCHES * BASE_MATCH_PTS

---@type integer[][] game grid
Grid = {}

---@type Player table containing player information
Player = {}

---@type States current state of the cartridge
CartState = STATES.title_screen

---@type HighScore[] high score
Leaderboard = {}

---@type integer frame counter for state transitions / pauses
FrameCounter = 0

--- Initialize the grid with all holes
function InitGrid()
	for y = 1, 6 do
		Grid[y] = {}
		for x = 1, 6 do
			Grid[y][x] = 0
		end
	end
end

--- Initialize the player for starting the game
function InitPlayer()
	---@type Player
	Player = {
		grid_cursor = { x = 3, y = 3 },
		score = 0,
		init_level_score = 0,
		level_threshold = L1_THRESHOLD,
		level = 1,
		chances = 3,
		combo = 0,
		last_match = { move_score = 0, x = 0, y = 0, color = 0 },
		letter_ids = { 1, 1, 1 },
		placement = nil,
		score_cursor = SCORE_POSITIONS.first,
	}
end

--- swap the two gems (done by the player)
---@param gem1 Coords
---@param gem2 Coords
function SwapGems(gem1, gem2)
	local temp = Grid[gem1.y][gem1.x]
	Grid[gem1.y][gem1.x] = Grid[gem2.y][gem2.x]
	Grid[gem2.y][gem2.x] = temp
end

--- Clear a match on the grid at the specific coordinates (if possible). Only clears when the match has 3+ gems
---@param coords Coords coordinates of a single gem in the match
---@param byPlayer boolean whether the clearing was by the player or automatic
---@return boolean # whether the match clearing was successful
function ClearMatching(coords, byPlayer)
	if Grid[coords.y][coords.x] == 0 then
		return false
	end
	local match_list = FloodMatch(coords, {})
	if #match_list >= 3 then
		local gem_color = GEM_COLORS[Grid[coords.y][coords.x]]
		for _, matchCoord in pairs(match_list) do
			Grid[matchCoord.y][matchCoord.x] = 0
		end
		if byPlayer then
			Player.combo = Player.combo + 1
			sfx(min(Player.combo, 7), -1, 0, 4) -- combo sound effects are #1-7
			local move_score = MoveScore(Player.level, Player.combo, #match_list)
			Player.score = Player.score + move_score
			Player.last_match = { move_score = move_score, x = coords.x, y = coords.y, color = gem_color }
		end
		return true
	end
	if byPlayer then
		Player.last_match = { move_score = 0, x = 0, y = 0, color = 0 }
	end
	return false
end

function MoveScore(level, combo, match_size)
	local level_bonus = 2 * (level - 1)
	local base_level_points = level_bonus + BASE_MATCH_PTS
	local size_bonus = level_bonus * (match_size - 3)
	local combo_bonus = min(combo - 1, 6) * base_level_points
	return base_level_points + size_bonus + combo_bonus
end

--- Get the neighbors of the given coordinate
---@param gemCoords Coords
---@return Coords[] # array of neighbor coordinates
function Neighbors(gemCoords)
	local neighbors = {}
	if gemCoords.y ~= 1 then
		neighbors[#neighbors + 1] = { y = gemCoords.y - 1, x = gemCoords.x }
	end
	if gemCoords.y ~= 6 then
		neighbors[#neighbors + 1] = { y = gemCoords.y + 1, x = gemCoords.x }
	end
	if gemCoords.x ~= 1 then
		neighbors[#neighbors + 1] = { y = gemCoords.y, x = gemCoords.x - 1 }
	end
	if gemCoords.x ~= 6 then
		neighbors[#neighbors + 1] = { y = gemCoords.y, x = gemCoords.x + 1 }
	end
	return neighbors
end

--- Check whether a coordinate pair is in a coordinate list
---@param coordsList Coords[] list of coordinate pairs to search
---@param coords Coords coordinate pair to search for
---@return boolean # whether the coords was in the coords list
function Contains(coordsList, coords)
	for _, item in pairs(coordsList) do
		if item.y == coords.y and item.x == coords.x then
			return true
		end
	end
	return false
end

--- Find the list of gems that are in the same match as the given gem coordinate using flood filling
---@param gemCoords Coords current coordinates to search
---@param visited Coords[] list of visited coordinates. Start with "{}" if new match
---@return Coords[] # list of coordinates in the match
function FloodMatch(gemCoords, visited)
	-- mark the current cell as visited
	visited[#visited + 1] = gemCoords
	for _, neighbor in pairs(Neighbors(gemCoords)) do
		if not Contains(visited, neighbor) then
			if Grid[neighbor.y][neighbor.x] == Grid[gemCoords.y][gemCoords.x] then
				-- do recursion for all non-visited neighbors
				visited = FloodMatch(neighbor, visited)
			end
		end
	end
	return visited
end

-- do all actions for moving the grid cursor
function MoveGridCursor()
	if btnp(0) and Player.grid_cursor.x > 1 then
		-- move left
		Player.grid_cursor.x = Player.grid_cursor.x - 1
	elseif btnp(1) and Player.grid_cursor.x < 6 then
		-- move right
		Player.grid_cursor.x = Player.grid_cursor.x + 1
	elseif btnp(2) and Player.grid_cursor.y > 1 then
		-- move up
		Player.grid_cursor.y = Player.grid_cursor.y - 1
	elseif btnp(3) and Player.grid_cursor.y < 6 then
		-- move down
		Player.grid_cursor.y = Player.grid_cursor.y + 1
	end
end

-- do all actions for selecting which gem to swap
---@return Coords | nil # which gem was chosen to swap with the player's cursor
function SelectSwapping()
	---@type Coords | nil
	local swapping_gem = nil
	if btnp(0) and Player.grid_cursor.x > 1 then
		-- swap left
		swapping_gem = { y = Player.grid_cursor.y, x = Player.grid_cursor.x - 1 }
	elseif btnp(1) and Player.grid_cursor.x < 6 then
		-- swap right
		swapping_gem = { y = Player.grid_cursor.y, x = Player.grid_cursor.x + 1 }
	elseif btnp(2) and Player.grid_cursor.y > 1 then
		-- swap up
		swapping_gem = { y = Player.grid_cursor.y - 1, x = Player.grid_cursor.x }
	elseif btnp(3) and Player.grid_cursor.y < 6 then
		-- swap down
		swapping_gem = { y = Player.grid_cursor.y + 1, x = Player.grid_cursor.x }
	end
	return swapping_gem
end

--- Cycle through the initials' indices.
---@param letterID integer # current letter ID (1 to #INITIALS inclusive)
---@param isForward boolean whether the step is forward
---@return integer # next / previous letter ID
function StepInitials(letterID, isForward)
	if letterID > #ALLOWED_LETTERS then
		error("letter ID must be less than or equal to " .. #ALLOWED_LETTERS)
	elseif letterID < 1 then
		error("letter ID must be greater than or equal to 1")
	end

	-- undo 1-based indexing for modulo arithmetic
	local letterID_0 = letterID - 1
	if isForward then
		local step_0 = (letterID_0 + 1) % #ALLOWED_LETTERS
		-- redo 1-based indexing
		return step_0 + 1
	else
		local step_0 = (letterID_0 - 1) % #ALLOWED_LETTERS
		-- redo 1-based indexing
		return step_0 + 1
	end
end

-- Do all cursor moving actions for entering the high score
function MoveScoreCursor()
	if Player.score_cursor ~= SCORE_POSITIONS.first and btnp(0) then
		-- move left
		Player.score_cursor = Player.score_cursor - 1
	elseif Player.score_cursor ~= SCORE_POSITIONS.ok and btnp(1) then
		-- move right
		Player.score_cursor = Player.score_cursor + 1
	elseif Player.score_cursor ~= SCORE_POSITIONS.ok and btnp(2) then
		-- increment letter
		Player.letter_ids[Player.score_cursor] = StepInitials(Player.letter_ids[Player.score_cursor], true)
	elseif Player.score_cursor ~= SCORE_POSITIONS.ok and btnp(3) then
		-- decrement letter
		Player.letter_ids[Player.score_cursor] = StepInitials(Player.letter_ids[Player.score_cursor], false)
	end
end

---@return boolean # true if the player is done entering high score, false if not
function IsDoneEntering()
	if Player.score_cursor == SCORE_POSITIONS.ok and (btnp(4) or btnp(5)) then
		-- all done typing score
		return true
	end
	return false
end

--- Clear the matches on the grid.
---@param byPlayer boolean whether the match is made by the player
---@return boolean # whether any matches were cleared
function ClearGridMatches(byPlayer)
	local had_matches = false
	for y = 1, 6 do
		for x = 1, 6 do
			had_matches = had_matches or ClearMatching({ y = y, x = x }, byPlayer)
		end
	end
	return had_matches
end

--- Fill holes in the grid by dropping gems.
---@return boolean # whether the grid has any holes
function FillGridHoles()
	local has_holes = false
	for y = 6, 1, -1 do
		for x = 1, 6 do
			if Grid[y][x] == 0 then
				if y == 1 then
					Grid[y][x] = 1 + flr(rnd(N_GEMS))
				else
					has_holes = true
					-- printh("Found a hole at " .. x .. "," .. y)
					Grid[y][x] = Grid[y - 1][x]
					Grid[y - 1][x] = 0
				end
			end
		end
	end
	return has_holes
end

--- Increase the player level and perform associated actions
function LevelUp()
	Player.level = Player.level + 1
	Player.init_level_score = Player.score
	Player.level_threshold = (
		Player.init_level_score + (L1_MATCHES + 20 * (Player.level - 1)) * (2 * (Player.level - 1) + BASE_MATCH_PTS)
	)
end

--- Get the corresponding ordinal indicator for the place number (e.g., 5th for 5)
---@param place integer
---@return string
function OrdinalIndicator(place)
	if place == 1 then
		return "st"
	elseif place == 2 then
		return "nd"
	elseif place == 3 then
		return "rd"
	elseif 4 <= place and place <= 10 then
		return "th"
	else
		error("only works for 1-10")
	end
end

--- Get the color of the score position for drawing the high score UI
---@param score_position ScorePositions
function HSColor(score_position)
	local color = 7
	if score_position == Player.score_cursor then
		color = 11
	end
	return color
end

--- Play the corresponding music for the given level number
---@param level integer current level number
function PlayLevelMusic(level)
	local musicID = (level % #LEVEL_MUSIC) + 1
	music(LEVEL_MUSIC[musicID])
end

function DrawInitialEntering()
	print(ALLOWED_LETTERS[Player.letter_ids[1]], 16, 36, HSColor(SCORE_POSITIONS.first))
	if Player.score_cursor == SCORE_POSITIONS.first then
		rect(16, 36 + 6, 16 + 2, 36 + 6, 11)
	end
	print(ALLOWED_LETTERS[Player.letter_ids[2]], 21, 36, HSColor(SCORE_POSITIONS.second))
	if Player.score_cursor == SCORE_POSITIONS.second then
		rect(21, 36 + 6, 21 + 2, 36 + 6, 11)
	end
	print(ALLOWED_LETTERS[Player.letter_ids[3]], 26, 36, HSColor(SCORE_POSITIONS.third))
	if Player.score_cursor == SCORE_POSITIONS.third then
		rect(26, 36 + 6, 26 + 2, 36 + 6, 11)
	end
	print("ok", 31, 36, HSColor(SCORE_POSITIONS.ok))
	if Player.score_cursor == SCORE_POSITIONS.ok then
		rect(31, 36 + 6, 31 + 6, 36 + 6, 11)
	end
end

function _init()
	cls(0)
	music(24)
	InitPlayer()
	InitGrid()
	LoadLeaderboard(Leaderboard, VERSION)
	menuitem(1, "reset scores", function()
		ResetLeaderboard(Leaderboard)
	end)
end

-- selene: allow(if_same_then_else)
function _draw()
	if CartState == STATES.title_screen then
		DrawTitleBG()
		DrawTitleFG(VERSION)
	elseif CartState == STATES.credits then
		DrawTitleBG()
		DrawCredits()
	elseif CartState == STATES.game_init then
		DrawGameBG()
		DrawHUD(Player)
	elseif CartState == STATES.generate_grid then
		DrawGameBG()
		DrawHUD(Player)
	elseif CartState == STATES.game_idle then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 7)
	elseif CartState == STATES.swap_select then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 11)
	elseif CartState == STATES.player_matching then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 1)
	elseif CartState == STATES.show_match_points then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 1)
		DrawMatchPoints(Player)
	elseif CartState == STATES.fill_grid then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 1)
	elseif CartState == STATES.level_up then
		DrawGameBG()
		DrawHUD(Player)
		print("level " .. Player.level .. " complete", 16, 16, 7)
		print("get ready for level " .. Player.level + 1, 16, 22, 7)
	elseif CartState == STATES.game_over then
		DrawGameBG()
		DrawHUD(Player)
		print("game over", 46, 61, 7)
	elseif CartState == STATES.enter_high_score then
		DrawGameBG()
		DrawHUD(Player)
		print("nice job!", 16, 16, 7)
		print("you got " .. Player.placement .. OrdinalIndicator(Player.placement) .. " place", 16, 22, 7)
		print("enter your initials", 16, 28, 7)
		DrawInitialEntering()
	elseif CartState == STATES.high_scores then
		DrawTitleBG()
		DrawLeaderboard(Leaderboard)
	end
	-- print(tostr(CartState), 1, 1, 7)
	-- print(tostr(FrameCounter), 1, 7, 7)
end

function _update()
	if CartState == STATES.title_screen then
		-- state transitions
		if btnp(4) then
			CartState = STATES.game_init
		elseif btnp(5) then
			CartState = STATES.high_scores
		elseif btnp(3) then
			CartState = STATES.credits
		end
	elseif (CartState == STATES.credits) or (CartState == STATES.high_scores) then
		-- state transitions
		if btnp(4) or btnp(5) then
			CartState = STATES.title_screen
		end
	elseif CartState == STATES.game_init then
		-- state actions
		InitPlayer()
		InitGrid()
		-- state transitions
		CartState = STATES.generate_grid
	elseif CartState == STATES.generate_grid then
		-- state actions & transitions
		if not FillGridHoles() then
			if not ClearGridMatches(false) then
				CartState = STATES.game_idle
				PlayLevelMusic(Player.level)
			end
		end
	elseif CartState == STATES.game_idle then
		-- state actions
		MoveGridCursor()
		-- state transitions
		if Player.chances == -1 then
			Player.chances = 0
			music(0)
			FrameCounter = 0
			CartState = STATES.game_over
		elseif Player.score >= Player.level_threshold then
			FrameCounter = 0
			CartState = STATES.level_up
		elseif btnp(4) or btnp(5) then
			CartState = STATES.swap_select
		end
	elseif CartState == STATES.swap_select then
		-- state actions
		local swapping_gem = SelectSwapping()
		-- state transitions
		if btnp(4) or btnp(5) then
			CartState = STATES.game_idle
		elseif swapping_gem ~= nil then
			SwapGems(Player.grid_cursor, swapping_gem)
			Player.grid_cursor = swapping_gem
			CartState = STATES.player_matching
		end
	elseif CartState == STATES.player_matching then
		-- state actions
		MoveGridCursor()
		-- state transitions
		if ClearGridMatches(true) then
			FrameCounter = 0
			CartState = STATES.show_match_points
		else
			FrameCounter = 0
			CartState = STATES.fill_grid
		end
	elseif CartState == STATES.show_match_points then
		-- state actions
		MoveGridCursor()
		-- state transitions
		if FrameCounter == MATCH_FRAMES then
			CartState = STATES.player_matching
			FrameCounter = 0
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.fill_grid then
		-- state actions
		MoveGridCursor()
		-- state actions & transitions
		if FrameCounter % DROP_FRAMES == 0 then
			if not FillGridHoles() then
				CartState = STATES.combo_check
			end
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.combo_check then
		-- state actions & transitions
		if ClearGridMatches(true) then
			FrameCounter = 0
			CartState = STATES.show_match_points
		else
			if Player.combo == 0 then
				sfx(0, -1, 0, 3) -- "error" sound effect
				Player.chances = Player.chances - 1
			end
			Player.combo = 0
			CartState = STATES.game_idle
		end
	elseif CartState == STATES.level_up then
		-- state transitions
		if FrameCounter == 100 then
			LevelUp()
			InitGrid()
			CartState = STATES.generate_grid
			FrameCounter = 0
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.game_over then
		-- state actions & transitions
		if FrameCounter ~= 100 then
			FrameCounter = FrameCounter + 1
		elseif btnp(0) or btnp(1) or btnp(2) or btnp(3) or btnp(4) or btnp(5) then
			Player.placement = FindPlacement(Leaderboard, Player.score)
			if Player.placement == nil then
				CartState = STATES.high_scores
				music(24)
			else
				CartState = STATES.enter_high_score
			end
		end
	elseif CartState == STATES.enter_high_score then
		-- state actions
		MoveScoreCursor()
		-- state transitions
		if IsDoneEntering() then
			UpdateLeaderboard(Leaderboard, Player.letter_ids, Player.score)
			SaveLeaderboard(Leaderboard)
			music(24)
			CartState = STATES.high_scores
		end
	else
		error("invalid state")
	end
end
