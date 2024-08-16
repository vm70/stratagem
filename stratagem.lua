-- stratagem
-- by VM70

---@alias Coords [integer, integer]
---@alias Player {cursor: Coords, swapMode: integer, score: integer, initLevelScore: integer, levelThreshold: integer, level: integer, lives: integer, combo: integer}

---@enum States
STATES = {
	title_screen = 1,
	game_init = 2,
	gameplay = 3,
	level_up = 4,
	game_over = 5,
	high_scores = 6,
}

N_GEMS = 8

DROP_FRAMES = 1
MATCH_FRAMES = 20

---@type integer[] main PICO-8 colors of gems
GEM_COLORS = { 8, 9, 12, 11, 14, 7, 4, 13 }

BASE_MATCH_PTS = 1
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

TitleSprite = {
	width = 82,
	height = 31,
	y_offset = 10,
}

---@type integer current state of the cartridge
CartState = 2

--- Wait for a specified number of frames
---@param frames integer number of frames to wait
function Wait(frames)
	for _ = 1, frames do
		flip()
	end
end

--- Initialize the grid with random gems; remove matches and holes
function InitGrid()
	for y = 1, 6 do
		for x = 1, 6 do
			Grid[y][x] = 0
		end
	end
	while GridHasMatches() or GridHasHoles() do
		UpdateGrid(false)
	end
end

--- Initialize the player for starting the game
function InitPlayer()
	---@type Player
	Player = {
		cursor = { 3, 3 },
		swapMode = 0,
		score = 0,
		initLevelScore = 0,
		levelThreshold = LEVEL_1_THRESHOLD,
		level = 1,
		lives = 3,
		combo = 0,
	}
end

--- swap the two gems (done by the player)
---@param gem1 Coords
---@param gem2 Coords
function SwapGems(gem1, gem2)
	Player.swapMode = 2
	local temp = Grid[gem1[1]][gem1[2]]
	Grid[gem1[1]][gem1[2]] = Grid[gem2[1]][gem2[2]]
	Grid[gem2[1]][gem2[2]] = temp
	local gem1Matched = ClearMatching(gem1, true)
	local gem2Matched = ClearMatching(gem2, true)
	if not (gem1Matched or gem2Matched) then
		Player.lives = Player.lives - 1
	end
	UpdateGrid(true)
	while GridHasMatches() or GridHasHoles() do
		UpdateGrid(true)
	end
	Player.combo = 0
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
			_draw()
			print(moveScore, 16 * coords[2] + 1, 16 * coords[1] + 1, gemColor)
			Wait(MATCH_FRAMES)
		end
		return true
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
---@param visited Coords[] list of visited coordinates
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
	if Player.swapMode == 0 then
		-- move left
		if btnp(0) and Player.cursor[2] > 1 then
			Player.cursor[2] = Player.cursor[2] - 1
		end
		-- move right
		if btnp(1) and Player.cursor[2] < 6 then
			Player.cursor[2] = Player.cursor[2] + 1
		end
		-- move up
		if btnp(2) and Player.cursor[1] > 1 then
			Player.cursor[1] = Player.cursor[1] - 1
		end
		-- move down
		if btnp(3) and Player.cursor[1] < 6 then
			Player.cursor[1] = Player.cursor[1] + 1
		end
		-- start swapMode
		if btnp(4) or btnp(5) then
			Player.swapMode = 1
		end
	else
		-- swap left
		if btnp(0) and Player.cursor[2] > 1 then
			Player.cursor = { Player.cursor[1], Player.cursor[2] - 1 }
			SwapGems(Player.cursor, { Player.cursor[1], Player.cursor[2] + 1 })
			Player.swapMode = 0
		end
		-- swap right
		if btnp(1) and Player.cursor[2] < 6 then
			Player.cursor = { Player.cursor[1], Player.cursor[2] + 1 }
			SwapGems(Player.cursor, { Player.cursor[1], Player.cursor[2] - 1 })
			Player.swapMode = 0
		end
		-- swap up
		if btnp(2) and Player.cursor[1] > 1 then
			Player.cursor = { Player.cursor[1] - 1, Player.cursor[2] }
			SwapGems(Player.cursor, { Player.cursor[1] + 1, Player.cursor[2] })
			Player.swapMode = 0
		end
		-- swap down
		if btnp(3) and Player.cursor[1] < 6 then
			Player.cursor = { Player.cursor[1] + 1, Player.cursor[2] }
			SwapGems(Player.cursor, { Player.cursor[1] - 1, Player.cursor[2] })
			Player.swapMode = 0
		end
		-- cancel swap
		if btnp(4) or btnp(5) then
			Player.swapMode = 0
		end
	end
end

--- draw the cursor on the grid
function DrawCursor()
	-- 0011 -> 3
	-- 0011 -> 3
	-- 1100 -> C
	-- 1100 -> C
	local color
	if Player.swapMode == 0 then
		color = 7
	end
	if Player.swapMode == 1 then
		color = 11
	end
	if Player.swapMode ~= 2 then
		rect(
			16 * Player.cursor[2],
			16 * Player.cursor[1],
			16 * Player.cursor[2] + 15,
			16 * Player.cursor[1] + 15,
			color
		)
	end
end

function DrawGameBG()
	fillp(0x4E72)
	-- herringbone pattern
	-- 0100 -> 4
	-- 1110 -> E
	-- 0111 -> 7
	-- 0010 -> 2
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

--- Check whether the grid has 0's (holes)
---@return boolean # whether the grid has holes
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

--- Check whether the grid has matches
---@return boolean # whether the grid has matches
function GridHasMatches()
	for y = 1, 6 do
		for x = 1, 6 do
			if Grid[y][x] ~= 0 and #FloodMatch({ y, x }, {}) >= 3 then
				printh("Grid has matches")
				return true
			end
		end
	end
	return false
end

--- Update the grid by first clearing holes, then clearing matches
---@param byPlayer boolean
function UpdateGrid(byPlayer)
	-- Clear all holes first
	while GridHasHoles() do
		for y = 6, 1, -1 do
			for x = 1, 6 do
				if Grid[y][x] == 0 then
					if y == 1 then
						Grid[y][x] = 1 + flr(rnd(N_GEMS))
					else
						Grid[y][x] = Grid[y - 1][x]
						Grid[y - 1][x] = 0
					end
				end
			end
		end
		if byPlayer then
			_draw()
			Wait(DROP_FRAMES)
		end
	end
	-- Clear any matches currently on the grid
	for y = 1, 6 do
		for x = 1, 6 do
			ClearMatching({ y, x }, byPlayer)
		end
	end
end

--- Draw the HUD (score, lives, level progress bar, etc) on the screen
function DrawHUD()
	print("score:" .. Player.score, 17, 9, 7)
	print("lives:" .. Player.lives, 73, 9, 8)
	print("level:" .. Player.level, 49, 121, 7)
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

function _init()
	cls(0)
end

function _draw()
	if CartState == STATES.title_screen then
		DrawTitleScreen()
	elseif CartState == STATES.game_init then
		InitGrid()
		InitPlayer()
		DrawGameBG()
		DrawGrid()
		rectfill(14, 14, 113, 113, 0)
	elseif CartState == STATES.gameplay then
		DrawGameBG()
		DrawGrid()
		DrawCursor()
		DrawHUD()
	elseif CartState == STATES.level_up then
		rectfill(14, 14, 113, 113, 0)
	elseif CartState == STATES.game_over then
		DrawGameBG()
		DrawGrid()
		DrawHUD()
	elseif CartState == STATES.high_scores then
	end
end

function _update()
	if CartState == STATES.title_screen then
	elseif CartState == STATES.game_init then
		InitPlayer()
		InitGrid()
		CartState = STATES.gameplay
	elseif CartState == STATES.gameplay then
		UpdateCursor()
		if Player.score >= Player.levelThreshold then
			CartState = STATES.level_up
			Timer = 0
		elseif Player.lives == 0 then
			CartState = STATES.game_over
		end
	elseif CartState == STATES.level_up then
		if Timer ~= 100 then
			Timer = Timer + 1
		else
			Timer = 0
			LevelUp()
			CartState = STATES.gameplay
		end
	elseif CartState == STATES.game_over then
	elseif CartState == STATES.high_scores then
	end
end
