-- stratagem
-- by vm70

-----------------
--  constants  --
-----------------

---@alias Coords [integer, integer]
---@alias Player {cursor: Coords, swapping: boolean, score: integer, level: integer, lives: integer, combo: integer}

S_TITLE_SCREEN = 1
S_GAMEPLAY = 2
S_GAME_OVER = 3
S_HIGH_SCORES = 4

N_GEMS = 8

DROP_FRAMES = 2
MATCH_FRAMES = 20

---@type Coords[] gem sprite x & y coordinates
GEM_SPRITES = {
	{ 8, 0 },
	{ 24, 0 },
	{ 40, 0 },
	{ 56, 0 },
	{ 72, 0 },
	{ 88, 0 },
	{ 104, 0 },
	{ 8, 16 },
}

MATCH_3_PTS = 5

------------------------
--  global variables  --
------------------------

---@type integer[][]
Grid = {
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
	{ 0, 0, 0, 0, 0, 0 },
}

---@type integer current state of the cartridge
CartState = 2

-----------------
--  functions  --
-----------------

---@param frames integer
function Wait(frames)
	for _ = 1, frames do
		flip()
	end
end

---@return Player # player stats object
function InitGame()
	for y = 1, 6 do
		for x = 1, 6 do
			Grid[y][x] = 0
		end
	end
	return {
		cursor = { 3, 3 }, -- cursor y- and x- coordinates
		swapping = false,
		score = 0,
		level = 1,
		lives = 3,
		combo = 0,
	}
end

---@param gem1 Coords
---@param gem2 Coords
function SwapGems(gem1, gem2)
	printh("Swapping gem" .. gem1[1] .. "," .. gem1[2] .. " with " .. gem2[1] .. "," .. gem2[2])
	local temp = Grid[gem1[1]][gem1[2]]
	Grid[gem1[1]][gem1[2]] = Grid[gem2[1]][gem2[2]]
	Grid[gem2[1]][gem2[2]] = temp
	if not (ClearMatching(gem2, true) or ClearMatching(gem1, true)) then
		Player.lives = Player.lives - 1
	end
	UpdateGrid(true)
	while GridHasMatches() or GridHasHoles() do
		UpdateGrid(true)
	end
	Player.combo = 0
end

---@param coords Coords
---@param byPlayer boolean
---@return boolean
function ClearMatching(coords, byPlayer)
	if Grid[coords[1]][coords[2]] == 0 then
		return false
	end
	local matchList = FloodMatch(coords, {})
	if #matchList >= 3 then
		for _, matchCoord in pairs(matchList) do
			Grid[matchCoord[1]][matchCoord[2]] = 0
		end
		if byPlayer then
			Player.combo = Player.combo + 1
			local moveScore = Player.level * Player.combo * MATCH_3_PTS * (#matchList - 2)
			Player.score = Player.score + moveScore
			_draw()
			Wait(MATCH_FRAMES)
		end
		return true
	end
	return false
end

---@param gemCoords Coords
---@return Coords[]
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

---@param coordsList Coords[]
---@param coords Coords
function Contains(coordsList, coords)
	for _, item in pairs(coordsList) do
		if item[1] == coords[1] and item[2] == coords[2] then
			return true
		end
	end
	return false
end

---@param gemCoords Coords
---@param visited Coords[]
---@return Coords[]
function FloodMatch(gemCoords, visited)
	printh("Checking " .. gemCoords[1] .. "," .. gemCoords[2]..": ".."Gem ID"..Grid[gemCoords[1]][gemCoords[2]])
	-- mark the current cell as visited
	visited[#visited + 1] = gemCoords
	for _, neighbor in pairs(Neighbors(gemCoords)) do
		if not Contains(visited, neighbor) then
			if Grid[neighbor[1]][neighbor[2]] == Grid[gemCoords[1]][gemCoords[2]] then
				visited = FloodMatch(neighbor, visited)
			end
		end
	end
	return visited
end

function UpdateCursor()
	if not Player.swapping then
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
		-- start swapping
		if btnp(4) or btnp(5) then
			Player.swapping = true
		end
	else
		-- swap left
		if btnp(0) and Player.cursor[2] > 1 then
			Player.cursor = { Player.cursor[1], Player.cursor[2] - 1 }
			SwapGems(Player.cursor, { Player.cursor[1], Player.cursor[2] + 1 })
			Player.swapping = false
		end
		-- swap right
		if btnp(1) and Player.cursor[2] < 6 then
			Player.cursor = { Player.cursor[1], Player.cursor[2] + 1 }
			SwapGems(Player.cursor, { Player.cursor[1], Player.cursor[2] - 1 })
			Player.swapping = false
		end
		-- swap up
		if btnp(2) and Player.cursor[1] > 1 then
			Player.cursor = { Player.cursor[1] - 1, Player.cursor[2] }
			SwapGems(Player.cursor, { Player.cursor[1] + 1, Player.cursor[2] })
			Player.swapping = false
		end
		-- swap down
		if btnp(3) and Player.cursor[1] < 6 then
			Player.cursor = { Player.cursor[1] + 1, Player.cursor[2] }
			SwapGems(Player.cursor, { Player.cursor[1] - 1, Player.cursor[2] })
			Player.swapping = false
		end
		-- cancel swap
		if btnp(4) or btnp(5) then
			Player.swapping = false
		end
	end
	printh("Cursor is at " .. Player.cursor[1] .. "," .. Player.cursor[2])
end

-- draw the cursor on the grid
function DrawCursor(Player)
	-- fillp(0b0011001111001100)
	-- ternary expressions in Lua are cursed
	local color
	if Player.swapping then
		color = 7
	else
		color = 11
	end
	rect(16 * Player.cursor[2], 16 * Player.cursor[1], 16 * Player.cursor[2] + 15, 16 * Player.cursor[1] + 15, color)
end

function DrawGrid()
	rectfill(0, 0, 127, 127, 1)
	rectfill(16, 16, 111, 111, 0)
	for y = 1, 6 do
		for x = 1, 6 do
			local col = Grid[y][x]
			if col ~= 0 then
				sspr(GEM_SPRITES[col][1], GEM_SPRITES[col][2], 16, 16, 16 * x, 16 * y)
			end
		end
	end
end

function GridHasHoles()
	if Grid == nil then
		return false
	end
	for y = 1, 6 do
		for x = 1, 6 do
			if Grid[y][x] == 0 then
				printh("Grid has holes")
				return true
			end
		end
	end
	return false
end

function GridHasMatches()
	for y=1,6 do
		for x = 1, 6 do
			if Grid[y][x] ~= 0 and #FloodMatch({y, x}, {}) >= 3 then
				printh("Grid has matches")
				return true
			end
		end
	end
	return false
end

---@param byPlayer boolean
function UpdateGrid(byPlayer)
	while GridHasHoles() do
		for y = 1, 6 do
			for x = 1, 6 do
				if Grid[y][x] == 0 then
					if y == 1 then
						Grid[y][x] = 1 + flr(rnd(N_GEMS))
					else
						Grid[y][x] = Grid[y - 1][x]
						Grid[y - 1][x] = 0
					end
					if byPlayer then
						Wait(DROP_FRAMES)
						_draw()
					end
				end
			end
		end
	end
	-- Clear all matches second
	for y = 1, 6 do
		for x = 1, 6 do
			ClearMatching({y, x}, byPlayer)
		end
	end
end

function DrawHUD()
	print("score: ", 0, 0, 12, 1)
	print(Player.score, 24, 0, 12, 1)

	print("lives:", 64, 0, 8, 2)
	for i = 1, Player.lives do
		print("X", 81 + i * 6, 0, 8, 2)
	end
	print("level", 10, 122, 7)
	print(Player.level, 34, 122, 7)
	print("combo", 10, 116, 7)
	print(Player.combo, 34, 116, 7)
end

function _init()
	Player = InitGame()
	while GridHasMatches() or GridHasHoles() do
		UpdateGrid(false)
	end
end

function _draw()
	if CartState == S_GAMEPLAY then
		DrawGrid()
		DrawCursor(Player)
		DrawHUD()
	end
end

function _update()
	if CartState == S_GAMEPLAY then
		UpdateCursor()
	end
end
