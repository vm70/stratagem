-- Player controls.

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

-- do all actions for moving the grid cursor
---@param player Player
---@param mouse_mode integer
function MoveGridCursor(player, mouse_mode)
	if mouse_mode == 0 then
		if player.grid_cursor == nil then
			player.grid_cursor = { x = 1, y = 1 }
		end
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
	else
		if (16 <= stat(32) - 1) and (stat(32) - 1 <= 111) and (16 <= stat(33) - 1) and (stat(33) - 1 <= 111) then
			player.grid_cursor = {
				x = flr((stat(32) - 1) / 16),
				y = flr((stat(33) - 1) / 16),
			}
		else
			player.grid_cursor = nil
		end
	end
end

-- do all actions for selecting which gem to swap
---@param grid_cursor Coords | nil # player's grid cursor. May be nil from mouse controls.
---@param mouse_mode integer # whether or not the mouse is enabled
---@return Coords | nil # which gem was chosen to swap with the player's cursor
function SelectSwapping(grid_cursor, mouse_mode)
	---@type Coords | nil
	if grid_cursor == nil then
		return nil
	end
	local swapping_gem = nil
	if mouse_mode == 1 and MousePressed() then
		---@type Coords
		local mouse_location = {
			x = flr((stat(32) - 1) / 16),
			y = flr((stat(33) - 1) / 16),
		}
		if Contains(Neighbors(grid_cursor), mouse_location) then
			swapping_gem = mouse_location
			return swapping_gem
		end
	end
	if btnp(0) and grid_cursor.x > 1 then
		-- swap left
		swapping_gem = { y = grid_cursor.y, x = grid_cursor.x - 1 }
	elseif btnp(1) and grid_cursor.x < 6 then
		-- swap right
		swapping_gem = { y = grid_cursor.y, x = grid_cursor.x + 1 }
	elseif btnp(2) and grid_cursor.y > 1 then
		-- swap up
		swapping_gem = { y = grid_cursor.y - 1, x = grid_cursor.x }
	elseif btnp(3) and grid_cursor.y < 6 then
		-- swap down
		swapping_gem = { y = grid_cursor.y + 1, x = grid_cursor.x }
	end
	return swapping_gem
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
