-- stratagemSTATES.level
-- by VM70

---@alias Coords [integer, integer]
---@alias HighScore {initials: string, score: integer}
---@alias Match {move_score: integer, x: integer, y: integer, color: integer}
---@alias Player {grid_cursor: Coords, score: integer, initLevelScore: integer, levelThreshold: integer, level: integer, lives: integer, combo: integer, last_match: Match, letterIDs: integer[], placement: integer, score_cursor: ScorePositions}

---@enum States
_States = {
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
_ScorePositions = {
	first = 1,
	second = 2,
	third = 3,
	ok = 4,
}

---@type integer Number of gems in the game (max 8)
_NGems = 8

---@type integer Number of frames to wait before dropping new gems down
_DropFrames = 3

---@type integer Number of frames to wait to show the match points
_MatchFrames = 20

---@type integer[] main PICO-8 colors of gems
_GemColors = { 8, 9, 12, 11, 14, 7, 4, 13 }

---@type integer How many points a three-gem match scores on level 1
_BaseMatchPts = 3

---@type integer How many points needed to get to level 2
_L1Threshold = 80

---@type string Allowed initial characters for high scores
_Initials = "abcdefghijklmnopqrstuvwxyz0123456789 "

---@type integer value for no high score
_NoPlacement = 11

---@type integer[][] game grid
_Grid = {}

---@type Player table containing player information
_Player = {}

---@type integer[] background patterns
-- herringbone pattern
-- 0100 -> 4
-- 1110 -> E
-- 0111 -> 7
-- 0010 -> 2
_BGPatterns = { 0x4E72, 0xE724, 0x724E, 0x24E7 }

---@type {width: integer, height: integer, y_offset: integer} Title art sprite properties
_TitleSprite = {
	width = 82,
	height = 31,
	y_offset = 10,
}

---@type States current state of the cartridge
_CartState = _States.game_init

---@type HighScore[] high score
_Leaderboard = {}

---@type integer frame counter for state transitions / pauses
_FrameCounter = 0

--- Initialize the grid with all holes
function InitGrid()
	for y = 1, 6 do
		_Grid[y] = {}
		for x = 1, 6 do
			_Grid[y][x] = 0
		end
	end
end

--- Initialize the player for starting the game
function InitPlayer()
	---@type Player
	_Player = {
		grid_cursor = { 3, 3 },
		score = 0,
		initLevelScore = 0,
		levelThreshold = _L1Threshold,
		level = 1,
		lives = 3,
		combo = 0,
		last_match = { move_score = 0, x = 0, y = 0, color = 0 },
		letterIDs = { 1, 1, 1 },
		placement = 0,
		score_cursor = _ScorePositions.first,
	}
end

--- Initialize the high scores by reading from persistent memory
function LoadLeaderboard()
	cartdata("vm70_stratagem")
	for score_idx = 1, 10 do
		---@type integer[]
		local rawScoreData = {}
		for word = 1, 4 do
			rawScoreData[word] = dget(4 * (score_idx - 1) + word - 1)
		end
		if rawScoreData[1] == 0 then
			rawScoreData = { 1, 1, 1, (11 - score_idx) * 100 }
		end
		-- printh(rawScoreData[1])
		-- printh(rawScoreData[2])
		-- printh(rawScoreData[3])
		-- printh(rawScoreData[4])
		_Leaderboard[score_idx] = {
			initials = _Initials[rawScoreData[1]] .. _Initials[rawScoreData[2]] .. _Initials[rawScoreData[3]],
			score = rawScoreData[4],
		}
	end
end

function UpdateLeaderboard()
	local first = _Initials[_Player.letterIDs[1]]
	local second = _Initials[_Player.letterIDs[2]]
	local third = _Initials[_Player.letterIDs[3]]
	---@type HighScore
	local newHighScore = { initials = first .. second .. third, score = _Player.score }
	if 1 <= _Player.placement and _Player.placement <= 10 then
		add(_Leaderboard, newHighScore, _Player.placement)
		_Leaderboard[11] = nil
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
	for score_idx, score in ipairs(_Leaderboard) do
		local first = FindInString(_Initials, score.initials[1])
		dset(4 * (score_idx - 1) + 0, first)
		local second = FindInString(_Initials, score.initials[2])
		dset(4 * (score_idx - 1) + 1, second)
		local third = FindInString(_Initials, score.initials[3])
		dset(4 * (score_idx - 1) + 2, third)
		dset(4 * (score_idx - 1) + 3, score.score)
	end
end

--- swap the two gems (done by the player)
---@param gem1 Coords
---@param gem2 Coords
function SwapGems(gem1, gem2)
	local temp = _Grid[gem1[1]][gem1[2]]
	_Grid[gem1[1]][gem1[2]] = _Grid[gem2[1]][gem2[2]]
	_Grid[gem2[1]][gem2[2]] = temp
end

--- Clear a match on the grid at the specific coordinates (if possible). Only clears when the match has 3+ gems
---@param coords Coords coordinates of a single gem in the match
---@param byPlayer boolean whether the clearing was by the player or automatic
---@return boolean # whether the match clearing was successful
function ClearMatching(coords, byPlayer)
	if _Grid[coords[1]][coords[2]] == 0 then
		return false
	end
	local matchList = FloodMatch(coords, {})
	if #matchList >= 3 then
		local gemColor = _GemColors[_Grid[coords[1]][coords[2]]]
		for _, matchCoord in pairs(matchList) do
			_Grid[matchCoord[1]][matchCoord[2]] = 0
		end
		if byPlayer then
			_Player.combo = _Player.combo + 1
			local moveScore = _Player.level * _Player.combo * _BaseMatchPts * (#matchList - 2)
			_Player.score = _Player.score + moveScore
			_Player.last_match = { move_score = moveScore, x = coords[2], y = coords[1], color = gemColor }
		end
		return true
	end
	_Player.last_match = { move_score = 0, x = 0, y = 0, color = 0 }
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
			if _Grid[neighbor[1]][neighbor[2]] == _Grid[gemCoords[1]][gemCoords[2]] then
				-- do recursion for all non-visited neighbors
				visited = FloodMatch(neighbor, visited)
			end
		end
	end
	return visited
end

--- Do all cursor updating actions
function UpdateGridCursor()
	if _CartState == _States.swap_select then
		-- player has chosen to swap gems
		if btnp(0) and _Player.grid_cursor[2] > 1 then
			-- swap left
			SwapGems(_Player.grid_cursor, { _Player.grid_cursor[1], _Player.grid_cursor[2] - 1 })
		elseif btnp(1) and _Player.grid_cursor[2] < 6 then
			-- swap right
			SwapGems(_Player.grid_cursor, { _Player.grid_cursor[1], _Player.grid_cursor[2] + 1 })
		elseif btnp(2) and _Player.grid_cursor[1] > 1 then
			-- swap up
			SwapGems(_Player.grid_cursor, { _Player.grid_cursor[1] - 1, _Player.grid_cursor[2] })
		elseif btnp(3) and _Player.grid_cursor[1] < 6 then
			-- swap down
			SwapGems(_Player.grid_cursor, { _Player.grid_cursor[1] + 1, _Player.grid_cursor[2] })
		end
		if btnp(0) or btnp(1) or btnp(2) or btnp(3) then
			_CartState = _States.player_matching
		end
	end
	-- move the cursor around the board while swapping or idle
	if btnp(0) and _Player.grid_cursor[2] > 1 then
		-- move left
		_Player.grid_cursor[2] = _Player.grid_cursor[2] - 1
	elseif btnp(1) and _Player.grid_cursor[2] < 6 then
		-- move right
		_Player.grid_cursor[2] = _Player.grid_cursor[2] + 1
	elseif btnp(2) and _Player.grid_cursor[1] > 1 then
		-- move up
		_Player.grid_cursor[1] = _Player.grid_cursor[1] - 1
	elseif btnp(3) and _Player.grid_cursor[1] < 6 then
		-- move down
		_Player.grid_cursor[1] = _Player.grid_cursor[1] + 1
	end
	-- idle <-> swapping
	if (btnp(4) or btnp(5)) and _CartState == _States.game_idle then
		-- idle to swapping
		_CartState = _States.swap_select
	elseif (btnp(4) or btnp(5)) and _CartState == _States.swap_select then
		-- swapping to idle
		_CartState = _States.game_idle
	end
end

function UpdateScoreCursor()
	if _Player.score_cursor ~= _ScorePositions.first and btnp(0) then
		-- move left
		_Player.score_cursor = _Player.score_cursor - 1
	elseif _Player.score_cursor ~= _ScorePositions.ok and btnp(1) then
		-- move right
		_Player.score_cursor = _Player.score_cursor + 1
	elseif _Player.score_cursor ~= _ScorePositions.ok and btnp(2) then
		-- increment letter
		_Player.letterIDs[_Player.score_cursor] =
			max((_Player.letterIDs[_Player.score_cursor] + 1) % (#_Initials + 1), 1)
	elseif _Player.score_cursor ~= _ScorePositions.ok and btnp(3) then
		-- decrement letter
		_Player.letterIDs[_Player.score_cursor] =
			max((_Player.letterIDs[_Player.score_cursor] - 1) % (#_Initials + 1), 1)
	elseif _Player.score_cursor == _ScorePositions.ok and (btnp(4) or btnp(5)) then
		-- all done typing score
		UpdateLeaderboard()
		SaveLeaderboard()
		_CartState = _States.high_scores
	end
end

--- draw the cursor on the grid
function DrawCursor()
	-- 0011 -> 3
	-- 0011 -> 3
	-- 1100 -> C
	-- 1100 -> C
	local color = 7
	if _CartState == _States.swap_select then
		color = 11
	end
	rect(
		16 * _Player.grid_cursor[2],
		16 * _Player.grid_cursor[1],
		16 * _Player.grid_cursor[2] + 15,
		16 * _Player.grid_cursor[1] + 15,
		color
	)
end

function DrawGameBG()
	fillp(_BGPatterns[1 + flr(time() % #_BGPatterns)])
	rectfill(0, 0, 128, 128, 0x21)
	fillp(0)
	rectfill(14, 14, 113, 113, 0)
	map(0, 0, 0, 0, 16, 16, 0)
end

function DrawGems()
	for y = 1, 6 do
		for x = 1, 6 do
			local color = _Grid[y][x]
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
	local hadMatches = false
	for y = 1, 6 do
		for x = 1, 6 do
			hadMatches = hadMatches or ClearMatching({ y, x }, byPlayer)
		end
	end
	return hadMatches
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
	local hasHoles = false
	for y = 6, 1, -1 do
		for x = 1, 6 do
			if _Grid[y][x] == 0 then
				if y == 1 then
					_Grid[y][x] = 1 + flr(rnd(_NGems))
				else
					hasHoles = true
					-- printh("Found a hole at " .. x .. "," .. y)
					_Grid[y][x] = _Grid[y - 1][x]
					_Grid[y - 1][x] = 0
				end
			end
		end
	end
	return hasHoles
end

--- Draw the HUD (score, lives, level progress bar, etc) on the screen
function DrawHUD()
	print("score:" .. _Player.score, 17, 9, 7)
	print("lives:" .. _Player.lives, 73, 9, 8)
	print("level:" .. _Player.level, 49, 121, 7)
	print("combo:" .. _Player.combo, 0, 0, 7)
	-- calculate level completion ratio
	local levelRatio = (_Player.score - _Player.initLevelScore) / (_Player.levelThreshold - _Player.initLevelScore)
	levelRatio = min(levelRatio, 1)
	local rectlen = (93 * levelRatio)
	rectfill(17, 114, 17 + rectlen, 117, 7)
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
	for i, score in ipairs(_Leaderboard) do
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
		_TitleSprite.width,
		_TitleSprite.height,
		64 - _TitleSprite.width / 2,
		_TitleSprite.y_offset,
		_TitleSprite.width,
		_TitleSprite.height
	)
	print("\142: start game", 12, 64, 7)
	print("\151: high scores", 12, 72, 7)
end

--- Increase the player level
function LevelUp()
	_Player.levelThreshold = _Player.score + _Player.levelThreshold * (_Player.level ^ 2)
	_Player.initLevelScore = _Player.score
	_Player.level = _Player.level + 1
	InitGrid()
end

--- Draw the player's match points where the gems were cleared
function DrawMatchPoints()
	if _Player.combo ~= 0 then
		print(
			chr(2) .. "0" .. _Player.last_match.move_score,
			16 * _Player.last_match.x + 1,
			16 * _Player.last_match.y + 1,
			_Player.last_match.color
		)
	end
end

function PlayerPlacement()
	for scoreIdx, score in ipairs(_Leaderboard) do
		if _Player.score > score.score then
			return scoreIdx
		end
	end
	return _NoPlacement
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
	if hs_state == _Player.score_cursor then
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
	if _CartState == _States.title_screen then
		DrawTitleBG()
		DrawTitleFG()
	elseif (_CartState == _States.game_init) or (_CartState == _States.generate_board) then
		DrawGameBG()
		DrawHUD()
	elseif (_CartState == _States.game_idle) or (_CartState == _States.swap_select) then
		DrawGameBG()
		DrawGems()
		DrawCursor()
		DrawHUD()
	elseif (_CartState == _States.update_board) or (_CartState == _States.player_matching) then
		DrawGameBG()
		DrawGems()
		DrawHUD()
		DrawMatchPoints()
	elseif _CartState == _States.level_up then
		DrawGameBG()
		DrawHUD()
		print("level " .. _Player.level .. " complete", 16, 16, 7)
		print("get ready for level " .. _Player.level + 1, 16, 22, 7)
	elseif _CartState == _States.game_over then
		DrawGameBG()
		print("game over", 16, 16, 7)
	elseif _CartState == _States.enter_high_score then
		DrawGameBG()
		print("nice job!", 16, 16, 7)
		print("you got " .. _Player.placement .. OrdinalIndicator(_Player.placement) .. " place", 16, 22, 7)
		print("enter your initials", 16, 28, 7)
		print(_Initials[_Player.letterIDs[1]], 16, 36, HSColor(_ScorePositions.first))
		print(_Initials[_Player.letterIDs[2]], 21, 36, HSColor(_ScorePositions.second))
		print(_Initials[_Player.letterIDs[3]], 26, 36, HSColor(_ScorePositions.third))
		print("ok", 31, 36, HSColor(_ScorePositions.ok))
	elseif _CartState == _States.high_scores then
		DrawTitleBG()
		DrawHighScores()
	end
end

function _update()
	if _CartState == _States.title_screen then
		if btnp(4) then
			_CartState = _States.game_init
		elseif btnp(5) then
			_CartState = _States.high_scores
		end
	elseif _CartState == _States.game_init then
		InitPlayer()
		InitGrid()
		_CartState = _States.generate_board
	elseif _CartState == _States.generate_board then
		if not FillGridHoles() then
			if not ClearGridMatches(false) then
				_CartState = _States.game_idle
			end
		end
	elseif _CartState == _States.game_idle then
		UpdateGridCursor()
		if _Player.score >= _Player.levelThreshold then
			_CartState = _States.level_up
			_FrameCounter = 0
		elseif _Player.lives == 0 then
			_CartState = _States.game_over
			_FrameCounter = 0
		end
	elseif _CartState == _States.swap_select then
		UpdateGridCursor()
	elseif _CartState == _States.update_board then
		if _FrameCounter ~= _MatchFrames then
			_FrameCounter = _FrameCounter + 1
		elseif (_FrameCounter - _MatchFrames) % _DropFrames == 0 then
			if not FillGridHoles() then
				_CartState = _States.player_matching
			end
		end
	elseif _CartState == _States.player_matching then
		if not ClearGridMatches(true) then
			if _Player.combo == 0 then
				_Player.lives = _Player.lives - 1
			end
			_Player.combo = 0
			_CartState = _States.game_idle
		else
			_CartState = _States.update_board
			_FrameCounter = 0
		end
	elseif _CartState == _States.level_up then
		if _FrameCounter ~= 100 then
			_FrameCounter = _FrameCounter + 1
		else
			LevelUp()
			_CartState = _States.generate_board
			_FrameCounter = 0
		end
	elseif _CartState == _States.game_over then
		if _FrameCounter ~= 100 then
			_FrameCounter = _FrameCounter + 1
		elseif btnp(4) or btnp(5) then
			_Player.placement = PlayerPlacement()
			-- printh("Player placement: " .. _Player.placement)
			if _Player.placement == _NoPlacement then
				_CartState = _States.high_scores
			else
				_CartState = _States.enter_high_score
			end
		end
	elseif _CartState == _States.enter_high_score then
		UpdateScoreCursor()
	elseif _CartState == _States.high_scores then
		if btnp(4) or btnp(5) then
			_CartState = _States.title_screen
		end
	end
end
