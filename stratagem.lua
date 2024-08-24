-- stratagem
-- by VM70

---@alias Coords [integer, integer]
---@alias HighScore {initials: string, score: integer}
---@alias Match {move_score: integer, x: integer, y: integer, color: integer}
---@alias Player {grid_cursor: Coords, score: integer, init_level_score: integer, level_threshold: integer, level: integer, lives: integer, combo: integer, last_match: Match, letter_ids: integer[], placement: integer, score_cursor: ScorePositions}

---@enum States
STATES = {
	title_screen = 1,
	game_init = 2,
	generate_board = 3,
	game_idle = 4,
	swap_select = 5,
	player_matching = 6,
	update_board = 7,
	level_up = 8,
	game_over = 9,
	enter_high_score = 10,
	high_scores = 11,
}

---@enum ScorePositions
SCORE_POSITIONS = {
	first = 1,
	second = 2,
	third = 3,
	ok = 4,
}

---@type integer Number of gems in the game (max 8)
N_GEMS = 8

---@type integer Number of frames to wait before dropping new gems down
DROP_FRAMES = 3

---@type integer Number of frames to wait to show the match points
MATCH_FRAMES = 20

---@type integer[] main PICO-8 colors of gems
GEM_COLORS = { 8, 9, 12, 11, 14, 7, 4, 13 }

---@type integer How many points a three-gem match scores on level 1
BASE_MATCH_PTS = 3

---@type integer How many points needed to get to level 2
L1_THRESHOLD = 80

---@type string Allowed initial characters for high scores
INITIALS = "abcdefghijklmnopqrstuvwxyz0123456789 "

---@type integer value for no high score
NO_PLACEMENT = 11

---@type integer[][] game grid
Grid = {}

---@type Player table containing player information
Player = {}

---@type integer[] background patterns
-- herringbone pattern
-- 0100 -> 4
-- 1110 -> E
-- 0111 -> 7
-- 0010 -> 2
BGPatterns = { 0x4E72, 0xE724, 0x724E, 0x24E7 }

---@type {width: integer, height: integer, y_offset: integer} Title art sprite properties
TITLE_SPRITE = {
	width = 82,
	height = 31,
	y_offset = 10,
}

---@type States current state of the cartridge
CartState = STATES.game_init

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
		grid_cursor = { 3, 3 },
		score = 0,
		init_level_score = 0,
		level_threshold = L1_THRESHOLD,
		level = 1,
		lives = 3,
		combo = 0,
		last_match = { move_score = 0, x = 0, y = 0, color = 0 },
		letter_ids = { 1, 1, 1 },
		placement = 0,
		score_cursor = SCORE_POSITIONS.first,
	}
end

--- Initialize the high scores by reading from persistent memory
function LoadLeaderboard()
	cartdata("vm70_stratagem")
	for score_idx = 1, 10 do
		---@type integer[]
		local raw_score_data = {}
		for word = 1, 4 do
			raw_score_data[word] = dget(4 * (score_idx - 1) + word - 1)
		end
		if raw_score_data[1] == 0 then
			raw_score_data = { 1, 1, 1, (11 - score_idx) * 100 }
		end
		-- printh(rawScoreData[1])
		-- printh(rawScoreData[2])
		-- printh(rawScoreData[3])
		-- printh(rawScoreData[4])
		Leaderboard[score_idx] = {
			initials = INITIALS[raw_score_data[1]] .. INITIALS[raw_score_data[2]] .. INITIALS[raw_score_data[3]],
			score = raw_score_data[4],
		}
	end
end

function UpdateLeaderboard()
	local first = INITIALS[Player.letter_ids[1]]
	local second = INITIALS[Player.letter_ids[2]]
	local third = INITIALS[Player.letter_ids[3]]
	---@type HighScore
	local new_high_score = { initials = first .. second .. third, score = Player.score }
	if 1 <= Player.placement and Player.placement <= 10 then
		add(Leaderboard, new_high_score, Player.placement)
		Leaderboard[11] = nil
	end
end

---@param str string
---@param wantChar string
function FindInString(str, wantChar)
	for idx = 1, #str do
		if str[idx] == wantChar then
			return idx
		end
	end
	return -1
end

function SaveLeaderboard()
	for score_idx, score in ipairs(Leaderboard) do
		local first = FindInString(INITIALS, score.initials[1])
		dset(4 * (score_idx - 1) + 0, first)
		local second = FindInString(INITIALS, score.initials[2])
		dset(4 * (score_idx - 1) + 1, second)
		local third = FindInString(INITIALS, score.initials[3])
		dset(4 * (score_idx - 1) + 2, third)
		dset(4 * (score_idx - 1) + 3, score.score)
	end
end

--- swap the two gems (done by the player)
---@param gem1 Coords
---@param gem2 Coords
function SwapGems(gem1, gem2)
	local temp = Grid[gem1[1]][gem1[2]]
	Grid[gem1[1]][gem1[2]] = Grid[gem2[1]][gem2[2]]
	Grid[gem2[1]][gem2[2]] = temp
end

--- Clear a match on the grid at the specific coordinates (if possible). Only clears when the match has 3+ gems
---@param coords Coords coordinates of a single gem in the match
---@param byPlayer boolean whether the clearing was by the player or automatic
---@return boolean # whether the match clearing was successful
function ClearMatching(coords, byPlayer)
	if Grid[coords[1]][coords[2]] == 0 then
		return false
	end
	local match_list = FloodMatch(coords, {})
	if #match_list >= 3 then
		local gem_color = GEM_COLORS[Grid[coords[1]][coords[2]]]
		for _, matchCoord in pairs(match_list) do
			Grid[matchCoord[1]][matchCoord[2]] = 0
		end
		if byPlayer then
			Player.combo = Player.combo + 1
			sfx(min(Player.combo, 7))
			local move_score = Player.level * Player.combo * BASE_MATCH_PTS * (#match_list - 2)
			Player.score = Player.score + move_score
			Player.last_match = { move_score = move_score, x = coords[2], y = coords[1], color = gem_color }
		end
		return true
	end
	if byPlayer then
		Player.last_match = { move_score = 0, x = 0, y = 0, color = 0 }
	end
	return false
end

--- Get the neighbors of the given coordinate
---@param gemCoords Coords
---@return Coords[] # array of neighbor coordinates
function Neighbors(gemCoords)
	local neighbors = {}
	if gemCoords[1] ~= 1 then
		neighbors[#neighbors + 1] = { gemCoords[1] - 1, gemCoords[2] }
	end
	if gemCoords[1] ~= 6 then
		neighbors[#neighbors + 1] = { gemCoords[1] + 1, gemCoords[2] }
	end
	if gemCoords[2] ~= 1 then
		neighbors[#neighbors + 1] = { gemCoords[1], gemCoords[2] - 1 }
	end
	if gemCoords[2] ~= 6 then
		neighbors[#neighbors + 1] = { gemCoords[1], gemCoords[2] + 1 }
	end
	return neighbors
end

--- Check whether a coordinate pair is in a coordinate list
---@param coordsList Coords[] list of coordinate pairs to search
---@param coords Coords coordinate pair to search for
---@return boolean # whether the coords was in the coords list
function Contains(coordsList, coords)
	for _, item in pairs(coordsList) do
		if item[1] == coords[1] and item[2] == coords[2] then
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
			if Grid[neighbor[1]][neighbor[2]] == Grid[gemCoords[1]][gemCoords[2]] then
				-- do recursion for all non-visited neighbors
				visited = FloodMatch(neighbor, visited)
			end
		end
	end
	return visited
end

--- Do all cursor updating actions
function UpdateGridCursor()
	if CartState == STATES.swap_select then
		-- player has chosen to swap gems
		if btnp(0) and Player.grid_cursor[2] > 1 then
			-- swap left
			SwapGems(Player.grid_cursor, { Player.grid_cursor[1], Player.grid_cursor[2] - 1 })
		elseif btnp(1) and Player.grid_cursor[2] < 6 then
			-- swap right
			SwapGems(Player.grid_cursor, { Player.grid_cursor[1], Player.grid_cursor[2] + 1 })
		elseif btnp(2) and Player.grid_cursor[1] > 1 then
			-- swap up
			SwapGems(Player.grid_cursor, { Player.grid_cursor[1] - 1, Player.grid_cursor[2] })
		elseif btnp(3) and Player.grid_cursor[1] < 6 then
			-- swap down
			SwapGems(Player.grid_cursor, { Player.grid_cursor[1] + 1, Player.grid_cursor[2] })
		end
		if btnp(0) or btnp(1) or btnp(2) or btnp(3) then
			CartState = STATES.player_matching
		end
	end
	-- move the cursor around the board while swapping or idle
	if btnp(0) and Player.grid_cursor[2] > 1 then
		-- move left
		Player.grid_cursor[2] = Player.grid_cursor[2] - 1
	elseif btnp(1) and Player.grid_cursor[2] < 6 then
		-- move right
		Player.grid_cursor[2] = Player.grid_cursor[2] + 1
	elseif btnp(2) and Player.grid_cursor[1] > 1 then
		-- move up
		Player.grid_cursor[1] = Player.grid_cursor[1] - 1
	elseif btnp(3) and Player.grid_cursor[1] < 6 then
		-- move down
		Player.grid_cursor[1] = Player.grid_cursor[1] + 1
	end
	-- idle <-> swapping
	if (btnp(4) or btnp(5)) and CartState == STATES.game_idle then
		-- idle to swapping
		CartState = STATES.swap_select
	elseif (btnp(4) or btnp(5)) and CartState == STATES.swap_select then
		-- swapping to idle
		CartState = STATES.game_idle
	end
end

function UpdateScoreCursor()
	if Player.score_cursor ~= SCORE_POSITIONS.first and btnp(0) then
		-- move left
		Player.score_cursor = Player.score_cursor - 1
	elseif Player.score_cursor ~= SCORE_POSITIONS.ok and btnp(1) then
		-- move right
		Player.score_cursor = Player.score_cursor + 1
	elseif Player.score_cursor ~= SCORE_POSITIONS.ok and btnp(2) then
		-- increment letter
		Player.letter_ids[Player.score_cursor] = max((Player.letter_ids[Player.score_cursor] + 1) % (#INITIALS + 1), 1)
	elseif Player.score_cursor ~= SCORE_POSITIONS.ok and btnp(3) then
		-- decrement letter
		Player.letter_ids[Player.score_cursor] = max((Player.letter_ids[Player.score_cursor] - 1) % (#INITIALS + 1), 1)
	elseif Player.score_cursor == SCORE_POSITIONS.ok and (btnp(4) or btnp(5)) then
		-- all done typing score
		UpdateLeaderboard()
		SaveLeaderboard()
		CartState = STATES.high_scores
	end
end

--- draw the cursor on the grid
function DrawCursor()
	-- 0011 -> 3
	-- 0011 -> 3
	-- 1100 -> C
	-- 1100 -> C
	local color = 7
	if CartState == STATES.swap_select then
		color = 11
	end
	rect(
		16 * Player.grid_cursor[2],
		16 * Player.grid_cursor[1],
		16 * Player.grid_cursor[2] + 15,
		16 * Player.grid_cursor[1] + 15,
		color
	)
end

function DrawGameBG()
	fillp(BGPatterns[1 + flr(time() % #BGPatterns)])
	rectfill(0, 0, 128, 128, 0x21)
	fillp(0)
	rectfill(14, 14, 113, 113, 0)
	map(0, 0, 0, 0, 16, 16, 0)
end

function DrawGems()
	for y = 1, 6 do
		for x = 1, 6 do
			local color = Grid[y][x]
			if color ~= 0 then
				sspr(16 * (color - 1), 16, 16, 16, 16 * x, 16 * y)
			end
			-- print(color, 16 * x, 16 * y, 11)
		end
	end
end

-- function GridHasMatches()
-- 	for y = 1, 6 do
-- 		for x = 1, 6 do
-- 			if #FloodMatch({ y, x }, {}) >= 3 then
-- 				return true
-- 			end
-- 		end
-- 	end
-- 	return false
-- end

--- Clear the matches on the grid.
---@param byPlayer boolean whether the match is made by the player
---@return boolean # whether any matches were cleared
function ClearGridMatches(byPlayer)
	local had_matches = false
	for y = 1, 6 do
		for x = 1, 6 do
			had_matches = had_matches or ClearMatching({ y, x }, byPlayer)
		end
	end
	return had_matches
end

-- function GridHasHoles()
-- 	for y = 1, 6 do
-- 		for x = 1, 6 do
-- 			if _Grid[y][x] == 0 then
-- 				return true
-- 			end
-- 		end
-- 	end
-- 	return false
-- end

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

--- Draw the HUD (score, lives, level progress bar, etc) on the screen
function DrawHUD()
	print("score:" .. Player.score, 17, 9, 7)
	print("lives:" .. Player.lives, 73, 9, 8)
	print("level:" .. Player.level, 49, 121, 7)
	print("combo:" .. Player.combo, 0, 0, 7)
	-- calculate level completion ratio
	local level_ratio = (Player.score - Player.init_level_score) / (Player.level_threshold - Player.init_level_score)
	level_ratio = min(level_ratio, 1)
	local rect_length = (93 * level_ratio)
	rectfill(17, 114, 17 + rect_length, 117, 7)
end

function DrawTitleBG()
	rectfill(0, 0, 128, 128, 1)
	-- draw wobbly function background
	for x = 0, 128, 3 do
		for y = 0, 128, 3 do
			local color = 1
			if
				cos(27 / 39 * x / 61 + y / 47 + time() / 23 + cos(29 / 31 * y / 67 + time() / 27))
				> sin(22 / 41 * x / 68 + y / 57 * time() / 32)
			then
				color = 2
			end
			pset(x, y, color)
		end
	end
	map(16, 0, 0, 0, 16, 16)
end

function DrawHighScores()
	for i, score in ipairs(Leaderboard) do
		local padded = "" .. i
		if #padded ~= 2 then
			padded = " " .. padded
		end
		print(padded .. ". " .. score.initials .. " " .. score.score, 64, 2 + 6 * i, 7)
	end
end

-- Draw the title screen
function DrawTitleFG()
	-- draw foreground title
	sspr(
		0,
		32,
		TITLE_SPRITE.width,
		TITLE_SPRITE.height,
		64 - TITLE_SPRITE.width / 2,
		TITLE_SPRITE.y_offset,
		TITLE_SPRITE.width,
		TITLE_SPRITE.height
	)
	print("\142: start game", 12, 64, 7)
	print("\151: high scores", 12, 72, 7)
end

--- Increase the player level
function LevelUp()
	Player.level_threshold = Player.score + Player.level_threshold * (Player.level ^ 2)
	Player.init_level_score = Player.score
	Player.level = Player.level + 1
	InitGrid()
end

--- Draw the player's match points where the gems were cleared
function DrawMatchPoints()
	if Player.combo ~= 0 then
		print(
			chr(2) .. "0" .. Player.last_match.move_score,
			16 * Player.last_match.x + 1,
			16 * Player.last_match.y + 1,
			Player.last_match.color
		)
	end
end

function PlayerPlacement()
	for scoreIdx, score in ipairs(Leaderboard) do
		if Player.score > score.score then
			return scoreIdx
		end
	end
	return NO_PLACEMENT
end

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

---@param hs_state ScorePositions
function HSColor(hs_state)
	local color = 7
	if hs_state == Player.score_cursor then
		color = 11
	end
	return color
end

function _init()
	cls(0)
	InitPlayer()
	InitGrid()
	LoadLeaderboard()
end

function _draw()
	if CartState == STATES.title_screen then
		DrawTitleBG()
		DrawTitleFG()
	elseif (CartState == STATES.game_init) or (CartState == STATES.generate_board) then
		DrawGameBG()
		DrawHUD()
	elseif (CartState == STATES.game_idle) or (CartState == STATES.swap_select) then
		DrawGameBG()
		DrawGems()
		DrawCursor()
		DrawHUD()
	elseif (CartState == STATES.update_board) or (CartState == STATES.player_matching) then
		DrawGameBG()
		DrawGems()
		DrawHUD()
		DrawMatchPoints()
	elseif CartState == STATES.level_up then
		DrawGameBG()
		DrawHUD()
		print("level " .. Player.level .. " complete", 16, 16, 7)
		print("get ready for level " .. Player.level + 1, 16, 22, 7)
	elseif CartState == STATES.game_over then
		DrawGameBG()
		print("game over", 16, 16, 7)
	elseif CartState == STATES.enter_high_score then
		DrawGameBG()
		print("nice job!", 16, 16, 7)
		print("you got " .. Player.placement .. OrdinalIndicator(Player.placement) .. " place", 16, 22, 7)
		print("enter your initials", 16, 28, 7)
		print(INITIALS[Player.letter_ids[1]], 16, 36, HSColor(SCORE_POSITIONS.first))
		print(INITIALS[Player.letter_ids[2]], 21, 36, HSColor(SCORE_POSITIONS.second))
		print(INITIALS[Player.letter_ids[3]], 26, 36, HSColor(SCORE_POSITIONS.third))
		print("ok", 31, 36, HSColor(SCORE_POSITIONS.ok))
	elseif CartState == STATES.high_scores then
		DrawTitleBG()
		DrawHighScores()
	end
end

function _update()
	if CartState == STATES.title_screen then
		if btnp(4) then
			CartState = STATES.game_init
		elseif btnp(5) then
			CartState = STATES.high_scores
		end
	elseif CartState == STATES.game_init then
		InitPlayer()
		InitGrid()
		CartState = STATES.generate_board
	elseif CartState == STATES.generate_board then
		if not FillGridHoles() then
			if not ClearGridMatches(false) then
				CartState = STATES.game_idle
			end
		end
	elseif CartState == STATES.game_idle then
		UpdateGridCursor()
		if Player.score >= Player.level_threshold then
			CartState = STATES.level_up
			FrameCounter = 0
		elseif Player.lives == 0 then
			CartState = STATES.game_over
			FrameCounter = 0
		end
	elseif CartState == STATES.swap_select then
		UpdateGridCursor()
	elseif CartState == STATES.update_board then
		if FrameCounter ~= MATCH_FRAMES then
			FrameCounter = FrameCounter + 1
		elseif (FrameCounter - MATCH_FRAMES) % DROP_FRAMES == 0 then
			if not FillGridHoles() then
				CartState = STATES.player_matching
			end
		end
	elseif CartState == STATES.player_matching then
		if not ClearGridMatches(true) then
			if Player.combo == 0 then
				sfx(0)
				Player.lives = Player.lives - 1
			end
			Player.combo = 0
			CartState = STATES.game_idle
		else
			CartState = STATES.update_board
			FrameCounter = 0
		end
	elseif CartState == STATES.level_up then
		if FrameCounter ~= 100 then
			FrameCounter = FrameCounter + 1
		else
			LevelUp()
			CartState = STATES.generate_board
			FrameCounter = 0
		end
	elseif CartState == STATES.game_over then
		if FrameCounter ~= 100 then
			FrameCounter = FrameCounter + 1
		elseif btnp(4) or btnp(5) then
			Player.placement = PlayerPlacement()
			-- printh("Player placement: " .. _Player.placement)
			if Player.placement == NO_PLACEMENT then
				CartState = STATES.high_scores
			else
				CartState = STATES.enter_high_score
			end
		end
	elseif CartState == STATES.enter_high_score then
		UpdateScoreCursor()
	elseif CartState == STATES.high_scores then
		if btnp(4) or btnp(5) then
			CartState = STATES.title_screen
		end
	end
end
