-- stratagem
-- by vm70

-----------------
--  constants  --
-----------------

S_TITLE_SCREEN = 1
S_GAMEPLAY = 2
S_GAME_OVER = 3
S_HIGH_SCORES = 4

N_GEMS = 8

---@type integer[][] gem sprite x & y coordinates
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

---@alias Player {cursor: [integer, integer], swapping: boolean}

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
	}
end

---@param cursorGem [integer, integer] # gem coordinates selected by cursor
---@param movedGem [integer, integer] # gem coordinates that cursor moves into
function SwapGems(cursorGem, movedGem)
	printh("Swapping gem" .. cursorGem[1] .. "," .. cursorGem[2] .. " with " .. movedGem[1] .. "," .. movedGem[2])
	local temp = Grid[cursorGem[1]][cursorGem[2]]
	Grid[cursorGem[1]][cursorGem[2]] = Grid[movedGem[1]][movedGem[2]]
	Grid[movedGem[1]][movedGem[2]] = temp
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
	if Grid == nil then
		return
	end
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
end

function _draw()
	if CartState == S_GAMEPLAY then
		DrawGrid()
		DrawCursor(Player)
	end
end

function _update()
	if CartState == S_GAMEPLAY then
		UpdateGrid()
		UpdateCursor(Player)
	end
end
