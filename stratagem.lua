-- stratagemSTATES.level
-- by VM70

---@alias Match { move_score: integer, x: integer, y: integer, color: integer}
---@alias Coords [integer, integer]
---@alias Player {cursor: Coords, score: integer, initLevelScore: integer, levelThreshold: integer, level: integer, lives: integer, combo: integer, last_match: Match}

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
	high_scores = 10,
}

---@type integer Number of gems in the game (max 8)
N_GEMS = 8

---@type integer Number of frames to wait before dropping new gems down
DROP_FRAMES = 3

---@type integer[] main PICO-8 colors of gems
GEM_COLORS = { 8, 9, 12, 11, 14, 7, 4, 13 }

---@type integer How many points a three-gem match scores on level 1
BASE_MATCH_PTS = 1

---@type integer How many points needed to get to level 2
LEVEL_1_THRESHOLD = 50 * BASE_MATCH_PTS

---@type integer[][] game grid
Grid = {
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
}

---@type integer[] background patterns
BGPatterns = { 0x4E72, 0xE724, 0x724E, 0x24E7 }
-- herringbone pattern
-- 0100 -> 4
-- 1110 -> E
-- 0111 -> 7
-- 0010 -> 2

---@type {width: integer, height: integer, y_offset: integer} Title art sprite properties
TitleSprite = {
	width = 82,
	height = 31,
	y_offset = 10,
}

---@type integer frame number for the current second, ranging from 0 to 30
Frame = 0

---@type integer current state of the cartridge
CartState = 2

--- Initialize the grid with all holes
function InitGrid()
	for y = 1, 6 do
		for x = 1, 6 do
			Grid[y][x] = 0
		end
	end
end

--- Initialize the player for starting the game
function InitPlayer()
	---@type Player
	Player = {
		cursor = { 3, 3 },
		score = 0,
		initLevelScore = 0,
		levelThreshold = LEVEL_1_THRESHOLD,
		level = 1,
		lives = 3,
		combo = 0,
		last_match = { move_score = 0, x = 0, y = 0, color = 0 },
	}
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
	local matchList = FloodMatch(coords, {})
	if #matchList >= 3 then
		local gemColor = GEM_COLORS[Grid[coords[1]][coords[2]]]
		for _, matchCoord in pairs(matchList) do
			Grid[matchCoord[1]][matchCoord[2]] = 0
		end
		if byPlayer then
			Player.combo = Player.combo + 1
			local moveScore = Player.level * Player.combo * BASE_MATCH_PTS * (#matchList - 2)
			Player.score = Player.score + moveScore
			Player.last_match = { move_score = moveScore, x = coords[2], y = coords[1], color = gemColor }
		end
		return true
	end
	Player.last_match = { move_score = 0, x = 0, y = 0, color = 0 }
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
function UpdateCursor()
	if CartState == STATES.swap_select then
		-- player has chosen to swap gems
		if btnp(0) and Player.cursor[2] > 1 then
			-- swap left
			SwapGems(Player.cursor, { Player.cursor[1], Player.cursor[2] - 1 })
		elseif btnp(1) and Player.cursor[2] < 6 then
			-- swap right
			SwapGems(Player.cursor, { Player.cursor[1], Player.cursor[2] + 1 })
		elseif btnp(2) and Player.cursor[1] > 1 then
			-- swap up
			SwapGems(Player.cursor, { Player.cursor[1] - 1, Player.cursor[2] })
		elseif btnp(3) and Player.cursor[1] < 6 then
			-- swap down
			SwapGems(Player.cursor, { Player.cursor[1] + 1, Player.cursor[2] })
		end
		if btnp(0) or btnp(1) or btnp(2) or btnp(3) then
			MatchFrame = Frame
			CartState = STATES.player_matching
		end
	end
	-- move the cursor around the board while swapping or idle
	if btnp(0) and Player.cursor[2] > 1 then
		-- move left
		Player.cursor[2] = Player.cursor[2] - 1
	elseif btnp(1) and Player.cursor[2] < 6 then
		-- move right
		Player.cursor[2] = Player.cursor[2] + 1
	elseif btnp(2) and Player.cursor[1] > 1 then
		-- move up
		Player.cursor[1] = Player.cursor[1] - 1
	elseif btnp(3) and Player.cursor[1] < 6 then
		-- move down
		Player.cursor[1] = Player.cursor[1] + 1
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
	rect(16 * Player.cursor[2], 16 * Player.cursor[1], 16 * Player.cursor[2] + 15, 16 * Player.cursor[1] + 15, color)
end

function DrawGameBG()
	fillp(BGPatterns[1 + flr(time() % #BGPatterns)])
	rectfill(0, 0, 128, 128, 0x21)
	fillp(0)
end

--- draw the game grid
function DrawGrid()
	rectfill(14, 14, 113, 113, 0)
	map(0, 0, 0, 0, 16, 16, 0)
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

function GridHasMatches()
	for y = 1, 6 do
		for x = 1, 6 do
			if #FloodMatch({ y, x }, {}) >= 3 then
				return true
			end
		end
	end
	return false
end

--- Clear the matches on the grid.
---@param byPlayer boolean whether the match is made by the player
---@return boolean # whether any matches were cleared
function ClearGridMatches(byPlayer)
	local hadMatches = false
	for y = 1, 6 do
		for x = 1, 6 do
			hadMatches = hadMatches or ClearMatching({ y, x }, byPlayer)
		end
	end
	return hadMatches
end

function GridHasHoles()
	for y = 1, 6 do
		for x = 1, 6 do
			if Grid[y][x] == 0 then
				return true
			end
		end
	end
	return false
end

--- Fill holes in the grid by dropping gems.
---@return boolean # whether the grid has any holes
function FillGridHoles()
	local hasHoles = false
	for y = 6, 1, -1 do
		for x = 1, 6 do
			if Grid[y][x] == 0 then
				if y == 1 then
					Grid[y][x] = 1 + flr(rnd(N_GEMS))
				else
					hasHoles = true
					printh("Found a hole at " .. x .. "," .. y)
					Grid[y][x] = Grid[y - 1][x]
					Grid[y - 1][x] = 0
				end
			end
		end
	end
	return hasHoles
end

--- Draw the HUD (score, lives, level progress bar, etc) on the screen
function DrawHUD()
	print("score:" .. Player.score, 17, 9, 7)
	print("lives:" .. Player.lives, 73, 9, 8)
	print("level:" .. Player.level, 49, 121, 7)
	print("combo:" .. Player.combo, 0, 0, 7)
	-- calculate level completion ratio
	local levelRatio = (Player.score - Player.initLevelScore) / (Player.levelThreshold - Player.initLevelScore)
	levelRatio = min(levelRatio, 1)
	local rectlen = (93 * levelRatio)
	rectfill(17, 114, 17 + rectlen, 117, 7)
end

-- Draw the title screen
function DrawTitleScreen()
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
	-- draw foreground title
	sspr(
		0,
		32,
		TitleSprite.width,
		TitleSprite.height,
		64 - TitleSprite.width / 2,
		TitleSprite.y_offset,
		TitleSprite.width,
		TitleSprite.height
	)
	print("\142: start game", 12, 64, 7)
	print("\151: high scores", 12, 72, 7)
end

--- Increase the player level
function LevelUp()
	Player.levelThreshold = Player.score + Player.levelThreshold * (2 ^ Player.level)
	Player.initLevelScore = Player.score
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

function _init()
	cls(0)
end

function _draw()
	if CartState == STATES.title_screen then
		DrawTitleScreen()
	elseif CartState == STATES.game_init then
		DrawGameBG()
		DrawGrid()
		DrawHUD()
	elseif CartState == STATES.generate_board then
		DrawGameBG()
		DrawGrid()
		DrawHUD()
	elseif CartState == STATES.game_idle then
		DrawGameBG()
		DrawGrid()
		DrawCursor()
		DrawHUD()
	elseif CartState == STATES.swap_select then
		DrawGameBG()
		DrawGrid()
		DrawCursor()
		DrawHUD()
	elseif CartState == STATES.update_board then
		DrawGameBG()
		DrawGrid()
		DrawHUD()
		DrawMatchPoints()
	elseif CartState == STATES.player_matching then
		DrawGameBG()
		DrawGrid()
		DrawHUD()
		DrawMatchPoints()
	elseif CartState == STATES.level_up then
		DrawGameBG()
		DrawGrid()
		DrawHUD()
	elseif CartState == STATES.game_over then
		DrawGameBG()
		DrawGrid()
		DrawHUD()
	elseif CartState == STATES.high_scores then
	end
end

function _update()
	Frame = (Frame + 1) % 30
	if CartState == STATES.title_screen then
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
		UpdateCursor()
		if Player.score >= Player.levelThreshold then
			CartState = STATES.level_up
			LevelUpCounter = 0
		elseif Player.lives == 0 then
			CartState = STATES.game_over
		end
	elseif CartState == STATES.swap_select then
		UpdateCursor()
	elseif CartState == STATES.update_board then
		if ((ClearMatchFrame - Frame) % 30) % DROP_FRAMES == 0 then
			if not FillGridHoles() then
				CartState = STATES.player_matching
			end
		end
	elseif CartState == STATES.player_matching then
		if not ClearGridMatches(true) then
			if Player.combo == 0 then
				Player.lives = Player.lives - 1
			end
			Player.combo = 0
			CartState = STATES.game_idle
		else
			ClearMatchFrame = Frame
			CartState = STATES.update_board
		end
	elseif CartState == STATES.level_up then
		if LevelUpCounter ~= 100 then
			LevelUpCounter = LevelUpCounter + 1
		else
			LevelUpCounter = 0
			LevelUp()
			CartState = STATES.generate_board
		end
	elseif CartState == STATES.game_over then
	elseif CartState == STATES.high_scores then
	end
end
