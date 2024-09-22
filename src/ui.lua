-- UI elements.

---@type {width: integer, height: integer, y_offset: integer} Title art sprite properties
TITLE_SPRITE = {
	width = 82,
	height = 31,
	y_offset = 10,
}

---@type integer[] main PICO-8 colors of gems
GEM_COLORS = { 8, 9, 12, 11, 14, 7, 4, 13 }

---@enum ScorePositions
SCORE_POSITIONS = {
	first = 1,
	second = 2,
	third = 3,
	ok = 4,
}

---@type integer[] background patterns
-- herringbone pattern
-- 0100 -> 4
-- 1110 -> E
-- 0111 -> 7
-- 0010 -> 2
BG_PATTERNS = { 0x4E72, 0xE724, 0x724E, 0x24E7 }

-- print with the anchor at the top-center
---@param str string
---@param x integer
---@param y integer
---@param col integer
function Printc(str, x, y, col)
	local width = print(str, -128, -128) + 128
	print(str, x - width / 2, y, col)
end
---
-- draw the cursor on the grid
---@param player Player
---@param color integer
function DrawCursor(player, color)
	-- fillp(0x33CC)
	-- -- 0011 -> 3
	-- -- 0011 -> 3
	-- -- 1100 -> C
	-- -- 1100 -> C
	rect(
		16 * player.grid_cursor.x,
		16 * player.grid_cursor.y,
		16 * player.grid_cursor.x + 15,
		16 * player.grid_cursor.y + 15,
		color
	)
	-- fillp(0)
end

-- draw the moving game background
function DrawGameBG()
	fillp(BG_PATTERNS[1 + flr(time() % #BG_PATTERNS)])
	rectfill(0, 0, 128, 128, 0x21)
	fillp(0)
	rectfill(14, 14, 113, 113, 0)
	map(0, 0, 0, 0, 16, 16, 0)
end

-- draw the gems in the grid
---@param grid integer[][]
function DrawGems(grid)
	for y = 1, 6 do
		for x = 1, 6 do
			local color = grid[y][x]
			if color ~= 0 then
				sspr(16 * (color - 1), 16, 16, 16, 16 * x, 16 * y)
			end
			-- print(color, 16 * x, 16 * y, 11)
		end
	end
end

-- left-pad / right-justify text.
---@param str string
---@param pad string
---@param length integer
function LeftPad(str, pad, length)
	if length < #str then
		error("desired length is less than input string")
	end
	local padded = "" .. str
	while #padded < length do
		padded = pad .. padded
	end
	return padded
end

-- Draw the HUD (score, chances, level progress bar, etc) on the screen
---@param player Player
function DrawHUD(player)
	print("score:" .. LeftPad(tostr(player.score), " ", 5), 17, 9, 7)
	print("chances:" .. max(player.chances, 0), 73, 9, 8)
	print("level:" .. player.level, 49, 121, 7)
	-- calculate level completion ratio
	local level_ratio = (player.score - player.init_level_score) / (player.level_threshold - player.init_level_score)
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

-- draw the leaderboard
---@param leaderboard HighScore[]
function DrawLeaderboard(leaderboard)
	Printc("high scores", 64, 8, 7)
	for i, score in ipairs(leaderboard) do
		-- use the format "XX. AAA: #####" for each score
		-- 14 chars * 3 + 13 gaps = 55 px
		local padded_place = LeftPad(tostr(i), " ", 2) .. ". "
		local padded_score = LeftPad(tostr(score.score), " ", 5)
		Printc(padded_place .. score.initials .. " " .. padded_score, 64, 8, 7)
	end
	Printc("\142/\151: return to title", 64, 94, 7)
end

function DrawCredits()
	Printc("credits", 64, 8, 7)
	print(
		'vincent "vm" mercator:\n lead dev,music,art\n\n@squaremango:\n gem sprite art\n\nbejeweled fans discord:\n playtesting',
		64 - 47,
		24,
		7
	)
	print("...and players like you.\nthank you!", 64 - 47, 78, 7)
	Printc("\142/\151: return to title", 64, 94, 7)
end

-- Draw the title screen
---@param version Version
function DrawTitleFG(version)
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
	print(
		"V" .. version.major .. "." .. version.minor .. "." .. version.patch,
		64 - TITLE_SPRITE.width / 2,
		TITLE_SPRITE.y_offset + TITLE_SPRITE.height + 1,
		7
	)
	Printc('by vincent "vm" mercator', 64, TITLE_SPRITE.y_offset + TITLE_SPRITE.height + 12, 7)
	Printc("\142: start game ", 64, 72, 7)
	Printc("\151: high scores", 64, 80, 7)
	Printc("\131: credits    ", 64, 88, 7)
end

-- Draw the point numbers for the player's match where the gems were cleared
function DrawMatchPoints(player)
	if player.combo ~= 0 then
		print(
			chr(2) .. "0" .. player.last_match.move_score,
			16 * player.last_match.x + 1,
			16 * player.last_match.y + 1,
			GEM_COLORS[player.last_match.gem_type]
		)
	end
end

---@param player Player
---@return boolean # true if the player is done entering high score, false if not
function IsDoneEntering(player)
	if player.score_cursor == SCORE_POSITIONS.ok and (btnp(4) or btnp(5)) then
		-- all done typing score
		return true
	end
	return false
end

-- do all actions for moving the grid cursor
---@param player Player
function MoveGridCursor(player)
	if btnp(0) and player.grid_cursor.x > 1 then
		-- move left
		player.grid_cursor.x = player.grid_cursor.x - 1
	elseif btnp(1) and player.grid_cursor.x < 6 then
		-- move right
		player.grid_cursor.x = player.grid_cursor.x + 1
	elseif btnp(2) and player.grid_cursor.y > 1 then
		-- move up
		player.grid_cursor.y = player.grid_cursor.y - 1
	elseif btnp(3) and player.grid_cursor.y < 6 then
		-- move down
		player.grid_cursor.y = player.grid_cursor.y + 1
	end
end

-- do all actions for selecting which gem to swap
---@param player Player
---@return Coords | nil # which gem was chosen to swap with the player's cursor
function SelectSwapping(player)
	---@type Coords | nil
	local swapping_gem = nil
	if btnp(0) and player.grid_cursor.x > 1 then
		-- swap left
		swapping_gem = { y = player.grid_cursor.y, x = player.grid_cursor.x - 1 }
	elseif btnp(1) and player.grid_cursor.x < 6 then
		-- swap right
		swapping_gem = { y = player.grid_cursor.y, x = player.grid_cursor.x + 1 }
	elseif btnp(2) and player.grid_cursor.y > 1 then
		-- swap up
		swapping_gem = { y = player.grid_cursor.y - 1, x = player.grid_cursor.x }
	elseif btnp(3) and player.grid_cursor.y < 6 then
		-- swap down
		swapping_gem = { y = player.grid_cursor.y + 1, x = player.grid_cursor.x }
	end
	return swapping_gem
end
