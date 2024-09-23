-- stratagem v0.3.0
-- by vincent mercator & co.

--# selene: allow(undefined_variable)

---@type Version
VERSION = {
	major = 0,
	minor = 3,
	patch = 0,
}

---@enum States
STATES = {
	title_screen = 1,
	credits = 2,
	game_init = 3,
	prepare_grid = 4,
	init_level_transition = 5,
	game_idle = 6,
	swap_select = 7,
	player_matching = 8,
	show_match_points = 9,
	fill_grid = 10,
	fill_grid_transition = 11,
	combo_check = 12,
	level_up_transition = 13,
	level_up = 14,
	game_over_transition = 15,
	game_over = 16,
	enter_high_score = 17,
	high_scores = 18,
}

---@type integer[] List of level music starting positions
LEVEL_MUSIC = { 2, 8, 32 }

---@type integer Number of gems in the game (max 8)
N_GEMS = 8

---@type integer Number of frames to wait before dropping new gems down
DROP_FRAMES = 2

---@type integer Number of frames to show level-up screen
LEVEL_UP_FRAMES = 100

---@type integer[][] game grid
Grid = {}

-- table containing player information
Player = {}

---@type States current state of the cartridge
CartState = STATES.title_screen

---@type HighScore[] high score
Leaderboard = {}

---@type integer frame counter for state transitions / pauses
FrameCounter = 0

-- Initialize the grid with all holes
function InitGrid()
	for y = 1, 6 do
		Grid[y] = {}
		for x = 1, 6 do
			Grid[y][x] = 0
		end
	end
end

-- Initialize the player for starting the game
function InitPlayer()
	---@type Player
	Player = {
		grid_cursor = { x = 3, y = 3 },
		score = 0,
		init_level_score = 0,
		level_threshold = L1_THRESHOLD,
		level = 1,
		chances = 3,
		combo = 0,
		last_match = { move_score = 0, x = 0, y = 0, gem_type = 1, match_list = {} },
		letter_ids = { 1, 1, 1 },
		placement = nil,
		score_cursor = SCORE_POSITIONS.first,
	}
end

-- Cycle through the initials' indices.
---@param letterID integer # current letter ID (1 to #INITIALS inclusive)
---@param isForward boolean whether the step is forward
---@return integer # next / previous letter ID
function StepInitials(letterID, isForward)
	if letterID > #ALLOWED_LETTERS then
		error("letter ID must be less than or equal to " .. #ALLOWED_LETTERS)
	elseif letterID < 1 then
		error("letter ID must be greater than or equal to 1")
	end

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
	local match_threshold = L1_MATCHES + 20 * (player.level - 1)
	local level_score_multiplier = BASE_MATCH_PTS * player.level
	player.level_threshold = player.init_level_score + match_threshold * level_score_multiplier
end

-- Get the corresponding ordinal indicator for the place number (e.g., 5th for 5)
---@param place integer
---@return string
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

function DrawInitialEntering()
	print(ALLOWED_LETTERS[Player.letter_ids[1]], 16, 36, HSColor(SCORE_POSITIONS.first))
	if Player.score_cursor == SCORE_POSITIONS.first then
		rect(16, 36 + 6, 16 + 2, 36 + 6, 11)
	end
	print(ALLOWED_LETTERS[Player.letter_ids[2]], 21, 36, HSColor(SCORE_POSITIONS.second))
	if Player.score_cursor == SCORE_POSITIONS.second then
		rect(21, 36 + 6, 21 + 2, 36 + 6, 11)
	end
	print(ALLOWED_LETTERS[Player.letter_ids[3]], 26, 36, HSColor(SCORE_POSITIONS.third))
	if Player.score_cursor == SCORE_POSITIONS.third then
		rect(26, 36 + 6, 26 + 2, 36 + 6, 11)
	end
	print("ok", 31, 36, HSColor(SCORE_POSITIONS.ok))
	if Player.score_cursor == SCORE_POSITIONS.ok then
		rect(31, 36 + 6, 31 + 6, 36 + 6, 11)
	end
end

function _init()
	cls(0)
	music(24)
	InitPlayer()
	InitGrid()
	LoadLeaderboard(Leaderboard, VERSION)
	menuitem(1, "reset scores", function()
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
	elseif CartState == STATES.game_init then
		DrawGameBG()
		DrawHUD(Player)
	elseif CartState == STATES.prepare_grid then
		DrawGameBG()
		DrawHUD(Player)
	elseif CartState == STATES.init_level_transition then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawWipe(FrameCounter, true)
	elseif CartState == STATES.game_idle then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 7)
	elseif CartState == STATES.swap_select then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 11)
	elseif CartState == STATES.player_matching then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 1)
	elseif CartState == STATES.show_match_points then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 1)
		DrawMatchAnimations(Player, FrameCounter)
	elseif CartState == STATES.fill_grid then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 1)
	elseif CartState == STATES.fill_grid_transition then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawCursor(Player, 1)
		-- DrawFallingGems(Grid)
	elseif CartState == STATES.level_up_transition then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawWipe(FrameCounter, false)
	elseif CartState == STATES.level_up then
		DrawGameBG()
		DrawHUD(Player)
		Printc("level " .. Player.level .. " complete!", 64, 32 - 3, 7)
		Printc("get ready for level " .. Player.level + 1, 64, 96 - 3, 7)
	elseif CartState == STATES.game_over_transition then
		DrawGameBG()
		DrawHUD(Player)
		DrawGems(Grid)
		DrawWipe(FrameCounter, false)
	elseif CartState == STATES.game_over then
		DrawGameBG()
		DrawHUD(Player)
		Printc("game over", 64, 64 - 3, 7)
	elseif CartState == STATES.enter_high_score then
		DrawGameBG()
		DrawHUD(Player)
		print("nice job!", 16, 16, 7)
		print("you got " .. Player.placement .. OrdinalIndicator(Player.placement) .. " place", 16, 22, 7)
		print("enter your initials", 16, 28, 7)
		DrawInitialEntering()
	elseif CartState == STATES.high_scores then
		DrawTitleBG()
		DrawLeaderboard(Leaderboard)
	end
	-- print(tostr(CartState), 1, 1, 7)
	-- print(tostr(FrameCounter), 1, 7, 7)
end

function _update()
	if CartState == STATES.title_screen then
		-- state transitions
		if btnp(4) then
			CartState = STATES.game_init
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
	elseif CartState == STATES.game_init then
		-- state actions
		InitPlayer()
		InitGrid()
		-- state transitions
		CartState = STATES.prepare_grid
	elseif CartState == STATES.prepare_grid then
		-- state actions & transitions
		if not FillGridHoles(Grid, N_GEMS) then
			if not ClearFirstGridMatch(Grid) then
				FrameCounter = 0
				CartState = STATES.init_level_transition
			end
		end
	elseif CartState == STATES.init_level_transition then
		-- state actions & transitions
		if FrameCounter == WIPE_FRAMES then
			CartState = STATES.game_idle
			PlayLevelMusic(Player.level)
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.game_idle then
		-- state actions
		MoveGridCursor(Player)
		-- state transitions
		if Player.chances == -1 then
			Player.chances = 0
			music(0)
			FrameCounter = 0
			CartState = STATES.game_over_transition
		elseif Player.score >= Player.level_threshold then
			FrameCounter = 0
			CartState = STATES.level_up_transition
		elseif btnp(4) or btnp(5) then
			CartState = STATES.swap_select
		end
	elseif CartState == STATES.swap_select then
		-- state actions
		local swapping_gem = SelectSwapping(Player)
		-- state transitions
		if btnp(4) or btnp(5) then
			CartState = STATES.game_idle
		elseif swapping_gem ~= nil then
			SwapGems(Grid, Player.grid_cursor, swapping_gem)
			Player.grid_cursor = swapping_gem
			CartState = STATES.player_matching
		end
	elseif CartState == STATES.player_matching then
		-- state actions
		MoveGridCursor(Player)
		-- state transitions
		if ClearFirstGridMatch(Grid, Player) then
			FrameCounter = 0
			CartState = STATES.show_match_points
		else
			FrameCounter = 0
			CartState = STATES.fill_grid
		end
	elseif CartState == STATES.show_match_points then
		-- state actions
		MoveGridCursor(Player)
		-- state transitions
		if FrameCounter == MATCH_FRAMES then
			FrameCounter = 0
			CartState = STATES.player_matching
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.fill_grid then
		-- state actions
		MoveGridCursor(Player)
		-- state actions & transitions
		if FillGridHoles(Grid, N_GEMS) then
			FrameCounter = 0
			CartState = STATES.fill_grid_transition
		else
			CartState = STATES.combo_check
		end
	elseif CartState == STATES.fill_grid_transition then
		if FrameCounter % DROP_FRAMES == 0 then
			CartState = STATES.fill_grid
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.combo_check then
		-- state actions & transitions
		if ClearFirstGridMatch(Grid, Player) then
			FrameCounter = 0
			CartState = STATES.show_match_points
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
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.level_up then
		-- state transitions
		if FrameCounter == LEVEL_UP_FRAMES then
			LevelUp(Player)
			InitGrid()
			FrameCounter = 0
			CartState = STATES.prepare_grid
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.game_over_transition then
		-- state actions & transitions
		if FrameCounter == WIPE_FRAMES then
			FrameCounter = 0
			CartState = STATES.game_over
		end
		FrameCounter = FrameCounter + 1
	elseif CartState == STATES.game_over then
		-- state actions & transitions
		if FrameCounter ~= LEVEL_UP_FRAMES then
			FrameCounter = FrameCounter + 1
		elseif btnp(0) or btnp(1) or btnp(2) or btnp(3) or btnp(4) or btnp(5) then
			Player.placement = FindPlacement(Leaderboard, Player.score)
			if Player.placement == nil then
				CartState = STATES.high_scores
				music(24)
			else
				CartState = STATES.enter_high_score
			end
		end
	elseif CartState == STATES.enter_high_score then
		-- state actions
		MoveScoreCursor()
		-- state transitions
		if IsDoneEntering(Player) then
			UpdateLeaderboard(Leaderboard, Player.letter_ids, Player.score)
			SaveLeaderboard(Leaderboard)
			music(24)
			CartState = STATES.high_scores
		end
	else
		error("invalid state")
	end
end
