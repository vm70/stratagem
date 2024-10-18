-- Player controls.

-- Set the mouse controls.
---@see MouseMode for how MouseMode is stored.
---@param mouse_mode integer Desired mouse mode control.
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

-- Do all actions for moving the player's grid cursor.
---@param player Player Player table.
---@param mouse_mode integer Mouse mode.
---@see MouseMode for how MouseMode is stored.
function MoveGridCursor(player, mouse_mode)
	if mouse_mode == 0 then
		if player.grid_cursor == nil then
			player.grid_cursor = { x = 3, y = 3 }
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

-- Do all actions for selecting which gem to swap.
---@param grid_cursor Coords | nil # player's grid cursor. May be nil due to mouse controls.
---@param mouse_mode integer # whether or not the mouse is enabled
---@see MouseMode for how MouseMode is stored.
---@return Coords | nil # which gem was chosen to swap with the player's cursor. May be nil if the choice is invalid.
function SelectSwapping(grid_cursor, mouse_mode)
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

-- Do all cursor-moving actions for entering the high score.
---@param player Player table.
function MoveScoreCursor(player)
	if player.score_cursor ~= SCORE_POSITIONS.first and btnp(0) then
		-- move left
		player.score_cursor = player.score_cursor - 1
	elseif player.score_cursor ~= SCORE_POSITIONS.ok and btnp(1) then
		-- move right
		player.score_cursor = player.score_cursor + 1
	elseif player.score_cursor ~= SCORE_POSITIONS.ok and btnp(2) then
		-- increment letter
		player.letter_ids[player.score_cursor] = StepInitials(player.letter_ids[player.score_cursor], true)
	elseif player.score_cursor ~= SCORE_POSITIONS.ok and btnp(3) then
		-- decrement letter
		player.letter_ids[player.score_cursor] = StepInitials(player.letter_ids[player.score_cursor], false)
	end
end

-- Signal whether the mouse has been pressed.
--
-- see PICO-8 Manual, sec. 6.13
---@return boolean
function MousePressed()
	return band(stat(34), 0x1) == 1
end

-- Check if any key (including the mouse) has been pressed.
---@return boolean
function AnyKeyPressed()
	if btnp(0) or btnp(1) or btnp(2) or btnp(3) or btnp(4) or btnp(5) then
		return true
	end
	if MouseMode == 1 and MousePressed() then
		return true
	end
	return false
end
