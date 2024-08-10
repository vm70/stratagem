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

DROP_FRAMES = 1
MATCH_FRAMES = 10

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

---@param cursorGem Coords # gem coordinates selected by cursor
---@param movedGem Coords # gem coordinates that cursor moves into
function SwapGems(cursorGem, movedGem)
	printh("Swapping gem" .. cursorGem[1] .. "," .. cursorGem[2] .. " with " .. movedGem[1] .. "," .. movedGem[2])
	local temp = Grid[cursorGem[1]][cursorGem[2]]
	Grid[cursorGem[1]][cursorGem[2]] = Grid[movedGem[1]][movedGem[2]]
	Grid[movedGem[1]][movedGem[2]] = temp
	if not (ClearMatching(movedGem, true) or ClearMatching(cursorGem, true)) then
		Player.lives = Player.lives - 1
	end
	while GridHasHoles() do
		UpdateGrid()
		Wait(DROP_FRAMES)
	end
end

---@param coords Coords
---@param byPlayer boolean
---@return boolean
function ClearMatching(coords, byPlayer)
	local matchList = FloodMatch(coords, {})
	if #matchList > 2 and byPlayer then
		Player.combo = Player.combo + 1
		local moveScore = Player.level * Player.combo * MATCH_3_PTS * (#matchList - 2)
		Player.score = Player.score + moveScore
		for _, matchCoord in pairs(matchList) do
			Grid[matchCoord[1]][matchCoord[2]] = 0
		end
		return true
	else
		return false
	end
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
	printh("Checking " .. gemCoords[1] .. "," .. gemCoords[2])
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

---@param player Player # player object
function UpdateCursor(player)
	if not player.swapping then
		-- move left
		if btnp(0) and player.cursor[2] > 1 then
			player.cursor[2] = player.cursor[2] - 1
		end
		-- move right
		if btnp(1) and player.cursor[2] < 6 then
			player.cursor[2] = player.cursor[2] + 1
		end
		-- move up
		if btnp(2) and player.cursor[1] > 1 then
			player.cursor[1] = player.cursor[1] - 1
		end
		-- move down
		if btnp(3) and player.cursor[1] < 6 then
			player.cursor[1] = player.cursor[1] + 1
		end
		-- start swapping
		if btnp(4) or btnp(5) then
			player.swapping = true
		end
	else
		-- swap left
		if btnp(0) and player.cursor[2] > 1 then
			SwapGems(player.cursor, { player.cursor[1], player.cursor[2] - 1 })
			player.cursor = { player.cursor[1], player.cursor[2] - 1 }
			player.swapping = false
		end
		-- swap right
		if btnp(1) and player.cursor[2] < 6 then
			SwapGems(player.cursor, { player.cursor[1], player.cursor[2] + 1 })
			player.cursor = { player.cursor[1], player.cursor[2] + 1 }
			player.swapping = false
		end
		-- swap up
		if btnp(2) and player.cursor[1] > 1 then
			SwapGems(player.cursor, { player.cursor[1] - 1, player.cursor[2] })
			player.cursor = { player.cursor[1] - 1, player.cursor[2] }
			player.swapping = false
		end
		-- swap down
		if btnp(3) and player.cursor[1] < 6 then
			SwapGems(player.cursor, { player.cursor[1] + 1, player.cursor[2] })
			player.cursor = { player.cursor[1] + 1, player.cursor[2] }
			player.swapping = false
		end
		-- cancel swap
		if btnp(4) or btnp(5) then
			player.swapping = false
		end
	end
	printh("Cursor is at " .. player.cursor[1] .. "," .. player.cursor[2])
end

-- draw the cursor on the grid
---@param player Player
function DrawCursor(player)
	-- fillp(0b0011001111001100)
	-- ternary expressions in Lua are cursed
	local color
	if player.swapping then
		color = 7
	else
		color = 11
	end
	rect(16 * player.cursor[2], 16 * player.cursor[1], 16 * player.cursor[2] + 15, 16 * player.cursor[1] + 15, color)
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
				return true
			end
		end
	end
	return false
end

function UpdateGrid()
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
				end
			end
		end
	end
end

function _init()
	Player = InitGame()
	UpdateGrid()
end

function _draw()
	if CartState == S_GAMEPLAY then
		DrawGrid()
		DrawCursor(Player)
	end
	print(#FloodMatch({ 1, 1 }, {}), 16 * 1, 16 * 1, 3)
end

function _update()
	if CartState == S_GAMEPLAY then
		UpdateCursor(Player)
	end
end
