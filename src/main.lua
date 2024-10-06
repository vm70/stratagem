-- stratagem v0.4.0
-- by vincent mercator & co.

---@type Version
VERSION = {
	major = 0,
	minor = 4,
	patch = 0,
}

---@enum States
STATES = {
	title_screen = 1,
	credits = 2,
	title_fade = 3,
	game_init = 4,
	prepare_grid = 5,
	game_transition = 6,
	game_idle = 7,
	swap_select_mouse_held = 8,
	swap_select = 9,
	swap_animation = 10,
	player_matching = 11,
	show_match_points = 12,
	fill_grid = 13,
	fill_grid_animation = 14,
	combo_check = 15,
	level_up_transition = 16,
	level_up = 17,
	game_over_transition = 18,
	game_over = 19,
	game_over_fade = 20,
	enter_high_score = 21,
	enter_high_score_fade = 22,
	high_scores = 23,
}

---@type integer[] List of level music starting positions
LEVEL_MUSIC = { 2, 8, 32 }

---@type integer Number of gems in the game (max 8)
N_GEMS = 8

---@type integer Number of frames to show level-up screen
LEVEL_UP_FRAMES = 100

---@type integer[][] game grid
Grid = {}

---@type boolean[][] falling grid
FallingGrid = {}

---@type Player # table containing player information
Player = {
	grid_cursor = nil,
	score = 0,
	init_level_score = 0,
	level_threshold = L1_THRESHOLD,
	level = 1,
	chances = 3,
	combo = 0,
	last_match = nil,
	letter_ids = { 1, 1, 1 },
	placement = nil,
	score_cursor = 1,
	swapping_gem = nil,
}

---@type States current state of the cartridge
CartState = STATES.title_screen

---@type HighScore[] high score
Leaderboard = {}

---@type integer frame counter for state transitions / pauses
FrameCounter = 0

---@type integer # mode for mouse controls. 0 if mouse is disabled, 1 if enabled.
MouseMode = 0

-- Initialize the grid with all holes
function InitGrids()
	for y = 1, 6 do
		Grid[y] = {}
		FallingGrid[y] = {}
		for x = 1, 6 do
			Grid[y][x] = 0
			FallingGrid[y][x] = true
		end
	end
end

-- Initialize the player for starting the game
function InitPlayer()
	Player.grid_cursor = { x = 3, y = 3 }
	Player.score = 0
	Player.init_level_score = 0
	Player.level_threshold = L1_THRESHOLD
	Player.level = 1
	Player.chances = 3
	Player.combo = 0
	Player.last_match = nil
	Player.placement = nil
	Player.score_cursor = SCORE_POSITIONS.first
	Player.swapping_gem = nil
end

-- Cycle through the initials' indices.
---@param letterID integer # current letter ID (1 to #INITIALS inclusive)
---@param isForward boolean whether the step is forward
---@return integer # next / previous letter ID
function StepInitials(letterID, isForward)
	assert((1 <= letterID) and (letterID <= #ALLOWED_LETTERS), "letter ID must be in allowed letter range")
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

-- Increase the player level and perform associated actions
---@param player Player
function LevelUp(player)
	player.level = player.level + 1
	player.init_level_score = player.score
	-- number of matches needed to advance to the next level (w/o bonus)
	local match_threshold = L1_MATCHES + 20 * (player.level - 1)
	-- the number of points for a 3-gem match on this level
	local base_level_points = ((player.level - 1) * 2) + BASE_MATCH_PTS
	player.level_threshold = player.init_level_score + match_threshold * base_level_points
end

-- Get the corresponding ordinal indicator for the place number (e.g., 5th for 5)
---@param place integer
---@return string
function OrdinalIndicator(place)
	assert((1 <= place) and (place <= 10), "only works for 1-10")
	if place == 1 then
		return "st"
	elseif place == 2 then
		return "nd"
	elseif place == 3 then
		return "rd"
	else
		return "th"
	end
end

-- Get the color of the score position for drawing the high score UI
---@param score_position ScorePositions
function HSColor(score_position)
	local color = 7
	if score_position == Player.score_cursor then
		color = 11
	end
	return color
end

-- Play the corresponding music for the given level number
---@param level integer current level number
function PlayLevelMusic(level)
	local musicID = (level % #LEVEL_MUSIC) + 1
	music(LEVEL_MUSIC[musicID])
end

function DrawInitialEntering(player)
	local first_str = ""
	local second_str = ""
	local third_str = ""
	local ok_str = ""
	if player.score_cursor == SCORE_POSITIONS.first then
		first_str = chr(2) .. "3"
	end
	first_str = first_str .. ALLOWED_LETTERS[player.letter_ids[1]] .. chr(2) .. "- "
	if player.score_cursor == SCORE_POSITIONS.second then
		second_str = chr(2) .. "3"
	end
	second_str = second_str .. ALLOWED_LETTERS[player.letter_ids[2]] .. chr(2) .. "- "
	if player.score_cursor == SCORE_POSITIONS.third then
		third_str = chr(2) .. "3"
	end
	third_str = third_str .. ALLOWED_LETTERS[player.letter_ids[3]] .. chr(2) .. "- "
	if player.score_cursor == SCORE_POSITIONS.ok then
		ok_str = chr(2) .. "3"
	end
	ok_str = ok_str .. "ok" .. chr(2) .. "- "
	Printc("your name: " .. first_str .. second_str .. third_str .. ok_str, 64, 64 + 24 - 3, 7)
end

---@param mouse_mode integer
function SetMouseControls(mouse_mode)
	assert((mouse_mode == 0) or (mouse_mode == 1), "Invalid memory configuration for mouse mode")
	MouseMode = mouse_mode
	dset(63, MouseMode)
	-- printh("MouseMode is " .. tostr(MouseMode))
	if MouseMode == 0 then
		menuitem(1, "mouse input: off", function()
			SetMouseControls(1)
		end)
	else
		menuitem(1, "mouse input: on", function()
			SetMouseControls(0)
		end)
	end
end

function _init()
	cartdata("vm70_stratagem_v" .. VERSION.major .. "_" .. VERSION.minor .. "_" .. VERSION.patch)
	LoadLeaderboard(Leaderboard)
	MouseMode = dget(63)
	poke(0x5f2d, 0x1)
	cls(0)
	music(24)
	InitPlayer()
	InitGrids()
	SetMouseControls(MouseMode)
	menuitem(2, "reset scores", function()
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
	elseif CartState == STATES.title_fade then
		DrawTitleBG()
		DrawTitleFG(VERSION)
		DrawFade(FrameCounter)
	elseif CartState == STATES.game_init then
		DrawGameBG()
		DrawHUD(Player)
	elseif CartState == STATES.prepare_grid then
		DrawGameBG()
		DrawHUD(Player)
	elseif CartState == STATES.game_transition then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawWipe(FrameCounter, true)
	elseif CartState == STATES.game_idle then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawCursor(Player.grid_cursor, 7)
	elseif (CartState == STATES.swap_select) or (CartState == STATES.swap_select_mouse_held) then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawCursor(Player.grid_cursor, 11)
	elseif CartState == STATES.swap_animation then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawGemSwapping(Grid, Player.grid_cursor, Player.swapping_gem, FrameCounter)
	elseif CartState == STATES.player_matching then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawCursor(Player.grid_cursor, 1)
	elseif CartState == STATES.show_match_points then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawCursor(Player.grid_cursor, 1)
		DrawMatchAnimations(Player, FrameCounter)
	elseif CartState == STATES.fill_grid then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid, FrameCounter)
		DrawCursor(Player.grid_cursor, 1)
	elseif CartState == STATES.fill_grid_animation then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid, FrameCounter)
		DrawCursor(Player.grid_cursor, 1)
	elseif CartState == STATES.combo_check then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawCursor(Player.grid_cursor, 1)
	elseif CartState == STATES.level_up_transition then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawWipe(FrameCounter, false)
	elseif CartState == STATES.level_up then
		DrawGameBG()
		DrawHUD(Player)
		Printc("level " .. Player.level .. " complete!", 64, 64 - 24 - 3, 7)
		Printc("get ready for level " .. Player.level + 1, 64, 64 + 24 - 3, 7)
	elseif CartState == STATES.game_over_transition then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid, FallingGrid)
		DrawWipe(FrameCounter, false)
	elseif CartState == STATES.game_over then
		DrawGameBG()
		DrawHUD(Player)
		Printc("no more chances!", 64, 64 - 18, 7)
		Printc(chr(6) .. "w" .. chr(6) .. "t" .. "game over", 64, 64 - 6, 7)
		Printc("press a key to continue", 64, 64 + 12, 7)
	elseif CartState == STATES.game_over_fade then
		DrawGameBG()
		DrawHUD(Player)
		Printc("no more chances!", 64, 64 - 18, 7)
		Printc(chr(6) .. "w" .. chr(6) .. "t" .. "game over", 64, 64 - 6, 7)
		Printc("press a key to continue", 64, 64 + 12, 7)
		DrawFade(FrameCounter)
	elseif CartState == STATES.enter_high_score then
		DrawGameBG()
		DrawHUD(Player)
		Printc("spectacular!", 64, 64 - 24 - 3, 7)
		Printc("you got " .. Player.placement .. OrdinalIndicator(Player.placement) .. " place", 64, 64 - 3, 7)
		DrawInitialEntering(Player)
	elseif CartState == STATES.enter_high_score_fade then
		DrawGameBG()
		DrawHUD(Player)
		Printc("spectacular!", 64, 64 - 24 - 3, 7)
		Printc("you got " .. Player.placement .. OrdinalIndicator(Player.placement) .. " place", 64, 64 - 3, 7)
		DrawInitialEntering(Player)
		DrawFade(FrameCounter)
	elseif CartState == STATES.high_scores then
		DrawTitleBG()
		DrawLeaderboard(Leaderboard)
	end
	if MouseMode == 1 then
		spr(15, stat(32) - 1, stat(33) - 1)
	end
	-- print(tostr(CartState), 1, 1, 7)
	-- print(tostr(FrameCounter), 1, 7, 7)
	-- print(tostr(stat(1) * 100), 1, 14, 7)
	-- print(tostr(Player.score_cursor), 1, 21, 7)
end

function _update()
	assert((1 <= CartState) and (CartState <= STATES.high_scores), "invalid state " .. tostr(CartState))
	if CartState == STATES.title_screen then
		-- state transitions
		if btnp(4) then
			FrameCounter = 0
			CartState = STATES.title_fade
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
	elseif CartState == STATES.title_fade then
		if FrameCounter == FADE_FRAMES then
			CartState = STATES.game_init
		else
			FrameCounter = FrameCounter + 1
		end
	elseif CartState == STATES.game_init then
		-- state actions
		InitPlayer()
		InitGrids()
		-- state transitions
		CartState = STATES.prepare_grid
	elseif CartState == STATES.prepare_grid then
		-- state actions & transitions
		if not FillGridHoles(Grid, FallingGrid, N_GEMS) then
			if not ClearFirstGridMatch(Grid) then
				FrameCounter = 0
				CartState = STATES.game_transition
			end
		end
	elseif CartState == STATES.game_transition then
		-- state actions & transitions
		if FrameCounter == WIPE_FRAMES then
			CartState = STATES.game_idle
			PlayLevelMusic(Player.level)
		else
			FrameCounter = FrameCounter + 1
		end
	elseif CartState == STATES.game_idle then
		-- state actions
		MoveGridCursor(Player, MouseMode)
		if MouseMode == 1 then
			Player.swapping_gem = nil
			Player.swapping_gem = SelectSwapping(Player.grid_cursor, MouseMode)
		end
		-- state transitions
		if Player.chances == -1 then
			Player.chances = 0
			music(0)
			FrameCounter = 0
			CartState = STATES.game_over_transition
		elseif MouseMode == 1 and Player.swapping_gem ~= nil then
			FrameCounter = 0
			CartState = STATES.swap_animation
		elseif MouseMode == 1 and Player.grid_cursor ~= nil and band(stat(34), 0x1) == 1 then
			CartState = STATES.swap_select_mouse_held
		elseif MouseMode == 0 and (btnp(4) or btnp(5)) then
			CartState = STATES.swap_select
		end
	elseif CartState == STATES.swap_select then
		-- state actions
		Player.swapping_gem = SelectSwapping(Player.grid_cursor, MouseMode)
		-- state transitions
		if
			(MouseMode == 1 and band(stat(34), 0x1) == 1 and Player.swapping_gem == nil)
			or (MouseMode == 0 and (btnp(4) or btnp(5)))
		then
			CartState = STATES.game_idle
		elseif Player.swapping_gem ~= nil then
			FrameCounter = 0
			CartState = STATES.swap_animation
		end
	elseif CartState == STATES.swap_select_mouse_held then
		Player.swapping_gem = SelectSwapping(Player.grid_cursor, MouseMode)
		if MouseMode == 0 or band(stat(34), 0x1) == 0 then
			CartState = STATES.swap_select
		elseif Player.swapping_gem ~= nil then
			FrameCounter = 0
			CartState = STATES.swap_animation
		end
	elseif CartState == STATES.swap_animation then
		-- state transitions
		if FrameCounter == SWAP_FRAMES then
			SwapGems(Grid, Player.grid_cursor, Player.swapping_gem)
			Player.grid_cursor = Player.swapping_gem
			FrameCounter = 0
			CartState = STATES.player_matching
		else
			FrameCounter = FrameCounter + 1
		end
	elseif CartState == STATES.player_matching then
		-- state actions
		MoveGridCursor(Player, MouseMode)
		-- state transitions
		if ClearFirstGridMatch(Grid, Player) then
			FrameCounter = 0
			CartState = STATES.show_match_points
		else
			CartState = STATES.fill_grid
		end
	elseif CartState == STATES.show_match_points then
		-- state actions
		MoveGridCursor(Player, MouseMode)
		-- state transitions
		if FrameCounter == MATCH_FRAMES then
			FrameCounter = 0
			CartState = STATES.player_matching
		else
			FrameCounter = FrameCounter + 1
		end
	elseif CartState == STATES.fill_grid then
		-- state actions
		FrameCounter = DROP_FRAMES
		MoveGridCursor(Player, MouseMode)
		-- state actions & transitions
		if FillGridHoles(Grid, FallingGrid, N_GEMS) then
			FrameCounter = 0
			CartState = STATES.fill_grid_animation
		else
			CartState = STATES.combo_check
		end
	elseif CartState == STATES.fill_grid_animation then
		-- state actions
		MoveGridCursor(Player, MouseMode)
		-- state transitions
		if FrameCounter == DROP_FRAMES - 1 then
			CartState = STATES.fill_grid
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.combo_check then
		-- state actions
		FrameCounter = DROP_FRAMES
		MoveGridCursor(Player, MouseMode)
		-- state transitions
		if ClearFirstGridMatch(Grid, Player) then
			FrameCounter = 0
			CartState = STATES.show_match_points
		elseif Player.score >= Player.level_threshold then
			FrameCounter = 0
			CartState = STATES.level_up_transition
		else
			if Player.combo == 0 then
				sfx(0, -1, 0, 3) -- "error" sound effect
				Player.chances = Player.chances - 1
			end
			Player.combo = 0
			CartState = STATES.game_idle
		end
	elseif CartState == STATES.level_up_transition then
		-- state actions & transitions
		if FrameCounter == WIPE_FRAMES then
			FrameCounter = 0
			CartState = STATES.level_up
		else
			FrameCounter = FrameCounter + 1
		end
	elseif CartState == STATES.level_up then
		-- state transitions
		if FrameCounter == LEVEL_UP_FRAMES then
			LevelUp(Player)
			InitGrids()
			FrameCounter = 0
			CartState = STATES.prepare_grid
		else
			FrameCounter = FrameCounter + 1
		end
	elseif CartState == STATES.game_over_transition then
		-- state actions & transitions
		if FrameCounter == WIPE_FRAMES then
			CartState = STATES.game_over
		else
			FrameCounter = FrameCounter + 1
		end
	elseif CartState == STATES.game_over then
		if btnp(0) or btnp(1) or btnp(2) or btnp(3) or btnp(4) or btnp(5) then
			Player.placement = FindPlacement(Leaderboard, Player.score)
			if Player.placement == nil then
				FrameCounter = 0
				CartState = STATES.game_over_fade
				music(24)
			else
				CartState = STATES.enter_high_score
			end
		end
	elseif (CartState == STATES.game_over_fade) or (CartState == STATES.enter_high_score_fade) then
		if FrameCounter == FADE_FRAMES then
			CartState = STATES.high_scores
		else
			FrameCounter = FrameCounter + 1
		end
	elseif CartState == STATES.enter_high_score then
		-- state actions
		MoveScoreCursor()
		-- state transitions
		if IsDoneEntering(Player) then
			UpdateLeaderboard(Leaderboard, Player.letter_ids, Player.score)
			SaveLeaderboard(Leaderboard)
			music(24)
			FrameCounter = 0
			CartState = STATES.enter_high_score_fade
		end
	end
end
