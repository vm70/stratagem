pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- stratagem
-- by vm70

-----------------
--  constants  --
-----------------

---@alias Coords [integer, integer]
---@alias Player {cursor: Coords, swapMode: integer, score: integer, initLevelScore: integer, levelThreshold: integer, level: integer, lives: integer, combo: integer}

S_TITLE_SCREEN = 1
S_GAME_INIT = 2
S_GAMEPLAY = 3
S_LEVEL_UP = 4
S_GAME_OVER = 5
S_HIGH_SCORES = 6

N_GEMS = 8

DROP_FRAMES = 1
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

---@type integer[] main PICO-8 colors of gems
GEM_COLORS = { 8, 9, 12, 11, 14, 7, 4, 13 }

BASE_MATCH_PTS = 1
LEVEL_1_THRESHOLD = 50 * BASE_MATCH_PTS

------------------------
--  global variables  --
------------------------

---@type integer[][] game grid
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
---@param coords Coords # coordinates of a single gem in the match
---@param byPlayer boolean # whether the clearing was by the player or automatic
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
---@param coordsList Coords[] # list of coordinate pairs to search
---@param coords Coords # coordinate pair to search for
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
---@param gemCoords Coords # current coordinates to search
---@param visited Coords[] # list of visited coordinates
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
	fillp(13260)
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
	fillp(0)
end

--- draw the game grid
function DrawGrid()
	fillp(20082)
	rectfill(0, 0, 128, 128, 0x21)
	fillp(0)
	rectfill(14, 14, 113, 113, 0)
	map(0, 0, 0, 0, 16, 16, 0)
	for y = 1, 6 do
		for x = 1, 6 do
			local color = Grid[y][x]
			if color ~= 0 then
				sspr(GEM_SPRITES[color][1], GEM_SPRITES[color][2], 16, 16, 16 * x, 16 * y)
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
				printh("Grid has holes")
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
	-- calculate level completion ratio
	local levelRatio = (Player.score - Player.initLevelScore) / (Player.levelThreshold - Player.initLevelScore)
	levelRatio = min(levelRatio, 1)
	local rectlen = (93 * levelRatio)
	rectfill(17, 114, 17 + rectlen, 117, 7)
end

--- Increase the player level
function LevelUp()
	CartState = S_GAME_INIT
	Player.levelThreshold = Player.score + Player.levelThreshold * (2 ^ Player.level)
	Player.initLevelScore = Player.score
	Player.level = Player.level + 1
	InitGrid()
	CartState = S_GAMEPLAY
end

function _init()
	InitPlayer()
	InitGrid()
end

function _draw()
	if CartState == S_TITLE_SCREEN then
		printh(CartState)
	elseif CartState == S_GAME_INIT then
		DrawGrid()
		rectfill(14, 14, 113, 113, 0)
	elseif CartState == S_GAMEPLAY then
		DrawGrid()
		DrawCursor()
		DrawHUD()
	elseif CartState == S_LEVEL_UP then
		printh(CartState)
	elseif CartState == S_GAME_OVER then
		printh(CartState)
	elseif CartState == S_HIGH_SCORES then
		printh(CartState)
	end
end

function _update()
	if CartState == S_TITLE_SCREEN then
		printh(CartState)
	elseif CartState == S_GAME_INIT then
		InitPlayer()
		InitGrid()
		CartState = S_GAMEPLAY
	elseif CartState == S_GAMEPLAY then
		UpdateCursor()
		if Player.score >= Player.levelThreshold then
			CartState = S_LEVEL_UP
		end
	elseif CartState == S_LEVEL_UP then
		LevelUp()
		CartState = S_GAMEPLAY
	elseif CartState == S_GAME_OVER then
		printh(CartState)
	elseif CartState == S_HIGH_SCORES then
		printh(CartState)
	end
end
__gfx__
0000000000000000000000000000000000155d0000000000000000000007700000aaaa0000077000077777700000000000000000000000000000000000000000
07000070d6666666666666666666666600155d000c7777700c777770007887000a9999a0000770001cccccc70000000000000000000000000000000000000000
007007005dddddddddddddddddddddd600155d0001cccc7dd1cccc70028888704994499a003bb7001cc111c70000000000000000000000000000000000000000
000770005dddddddddddddddddddddd600155d0001cccc7551cccc702888288749a9949a003bb7001c7cc1c70000000000000000000000000000000000000000
000770005dddddddddddddddddddddd600155d0001cccc7551cccc702887888749a9949a03b73b701c7cc1c70000000000000000000000000000000000000000
007007005dddddddddddddddddddddd600155d0001cccc7111cccc7002888870499aa99a03b73b701c777cc70000000000000000000000000000000000000000
0700007055555555555555555555555d00155d00011111c0011111c000288200049999403bbbbbb71cccccc70000000000000000000000000000000000000000
0000000000000000000000000000000000155d0000155d0000155d00000220000044440033333377011111100000000000000000000000000000000000000000
000000005ddddddddddddddddddddddd0000000000155d0000155d002ffff0000077770000000000006666000000000000000000000000000000000000000000
0000000015555555555555555555555d000000000c7777700c7777702eeeef000d6666700999999006dddd600000000000000000000000000000000000000000
0000000015555555555555555555555ddddddddd01cccc7dd1cccc702e22eef00d6dd6702aa444491dd11dd60000000000000000000000000000000000000000
0000000015555555555555555555555d5555555501cccc7551cccc702efe2eefd6766d67244222491d6001d60000000000000000000000000000000000000000
0000000015555555555555555555555d5555555501cccc7551cccc702eefe2efd6766d67249994491d6001d60000000000000000000000000000000000000000
0000000015555555555555555555555d1111111101cccc7111cccc7002eef2ef0d67767024444aa91dd66dd60000000000000000000000000000000000000000
0000000015555555555555555555555d00000000011111c0011111c0002eeeef0d6666700222222001dddd600000000000000000000000000000000000000000
000000001111111111111111111111150000000000000000000000000002222200dddd0000000000001111000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000770000000000000aaaa000000000777777777700000000007700000000ffffffff0000000000077777777000000000000000000000000066666600000
00000078870000000000aa9999aa0000001cccccccccc7000000007bb700000002eeeeeeef0000000000766666670000000000000000000000006dddddd60000
0000078888700000000a99999999a00001cccccccccccc700000003bb700000002e22222eef00000000d66dddd66700000099999999990000001dddddddd6000
00002882288700000049994444999a0001ccc1111111cc70000003bbbb70000002efefff2eef0000000d66d66d6670000094aaa444444900001ddd1111ddd600
0002882772887000004997aaaa499a0001cc7cccccc1cc70000003b73b70000002ef2eeef2eef00000d6676666d6670002444aaa4444449001ddd660011ddd60
00288788872887000499a49999a499a001cc7cccccc1cc7000003bb73bb7000002ef2eeeef2eef0000d6676666d66700024442222222449001dd66000011dd60
02887288887288700499a49999a499a001cc7cccccc1cc7000003b7bb3b7000002ef2eeeeef2eef00d667666666d6670024494444442449001dd60000001dd60
02887288887288700499a49999a499a001cc7cccccc1cc700003bb7bb3bb700002eef2eeeeef2ef00d667666666d6670024494444442449001dd60000001dd60
00288728882887000499a49999a499a001cc7cccccc1cc700003b7bbbb3b7000002eef2eeeef2ef000d6676666766700024499999994449001dd66000061dd60
000288722788700000499a4444799a0001cc7cccccc1cc70003bb7bbbb3bb7000002eef2eeef2ef000d667666676670002444444aaa4449001ddd660066ddd60
0000288778820000004999aaaa999a0001cc7777777ccc70003b7bbbbbb3b70000002eef222e2ef0000d66766766d000002444444aaa4200001ddd6666ddd600
0000028888200000000499999999a00001cccccccccccc7003bb77777733bb70000002eeffff2ef0000d66777766d00000022222222220000001dddddddd1000
00000028820000000000449999440000001cccccccccc70003bbbbbbbbbbbb700000002eeeeeeef00000d666666d0000000000000000000000001dddddd10000
000000022000000000000044440000000001111111111000033333333333377000000002222222f00000dddddddd000000000000000000000000011111100000
__map__
0000000000000000000000000000510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005141414141414141414141414060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0015141414141414141414141414160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
