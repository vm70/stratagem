-- Grid functions.

---@type integer How many points a three-gem match scores on level 1
BASE_MATCH_PTS = 3

---@type integer How many three-gem matches without combos should get you to level 2
L1_MATCHES = 50

---@type integer How many points needed to get to level 2
L1_THRESHOLD = L1_MATCHES * BASE_MATCH_PTS

-- swap the two gems (done by the player)
---@param grid integer[][]
---@param gem1 Coords
---@param gem2 Coords
function SwapGems(grid, gem1, gem2)
	local temp = grid[gem1.y][gem1.x]
	grid[gem1.y][gem1.x] = grid[gem2.y][gem2.x]
	grid[gem2.y][gem2.x] = temp
end

-- Fill holes in the grid by dropping gems.
---@param grid integer[][]
---@param falling_grid boolean[][]
---@param n_gems integer
---@return boolean # whether the grid has any holes
function FillGridHoles(grid, falling_grid, n_gems)
	local has_holes = false
	for y = 6, 1, -1 do
		for x = 1, 6 do
			if grid[y][x] == 0 then
				falling_grid[y][x] = true
				if y == 1 then
					grid[y][x] = 1 + flr(rnd(n_gems))
				else
					has_holes = true
					-- printh("Found a hole at " .. x .. "," .. y)
					grid[y][x] = grid[y - 1][x]
					grid[y - 1][x] = 0
				end
			else
				falling_grid[y][x] = false
			end
			has_holes = has_holes or falling_grid[y][x]
		end
	end
	return has_holes
end

-- Clear the first match on the grid, starting from the top-left corner.
---@param grid integer[][]
---@param player? Player whether the match is made by the player
---@return boolean # whether any matches were cleared
function ClearFirstGridMatch(grid, player)
	for y = 1, 6 do
		for x = 1, 6 do
			-- Only runs `ClearMatching` successfully once
			if ClearMatching(grid, { y = y, x = x }, player) then
				return true
			end
		end
	end
	return false
end

-- Clear a match on the grid at the specific coordinates (if possible). Only clears when the match has 3+ gems
---@param coords Coords coordinates of a single gem in the match
---@param player? Player
---@return boolean # whether the match clearing was successful
function ClearMatching(grid, coords, player)
	local gem_type = grid[coords.y][coords.x]
	if gem_type == 0 then
		return false
	end
	local match_list = FloodMatch(grid, coords, {})
	if #match_list >= 3 then
		for _, matchCoord in pairs(match_list) do
			grid[matchCoord.y][matchCoord.x] = 0
		end
		if player ~= nil then
			player.combo = player.combo + 1
			sfx(min(player.combo, 7), -1, 0, 4) -- combo sound effects are #1-7
			local move_score = MatchScore(player.level, player.combo, #match_list)
			player.score = player.score + move_score
			player.last_match =
				{ move_score = move_score, x = coords.x, y = coords.y, gem_type = gem_type, match_list = match_list }
		end
		return true
	end
	return false
end

-- Get the neighbors of the given coordinate
---@param gemCoords Coords
---@return Coords[] # array of neighbor coordinates
function Neighbors(gemCoords)
	local neighbors = {}
	if gemCoords.y ~= 1 then
		neighbors[#neighbors + 1] = { y = gemCoords.y - 1, x = gemCoords.x }
	end
	if gemCoords.y ~= 6 then
		neighbors[#neighbors + 1] = { y = gemCoords.y + 1, x = gemCoords.x }
	end
	if gemCoords.x ~= 1 then
		neighbors[#neighbors + 1] = { y = gemCoords.y, x = gemCoords.x - 1 }
	end
	if gemCoords.x ~= 6 then
		neighbors[#neighbors + 1] = { y = gemCoords.y, x = gemCoords.x + 1 }
	end
	return neighbors
end

-- Check whether a coordinate pair is in a coordinate list
---@param coordsList Coords[] list of coordinate pairs to search
---@param coords Coords coordinate pair to search for
---@return boolean # whether the coords was in the coords list
function Contains(coordsList, coords)
	for _, item in pairs(coordsList) do
		if item.y == coords.y and item.x == coords.x then
			return true
		end
	end
	return false
end

-- Find the list of gems that are in the same match as the given gem coordinate using flood filling
---@param grid integer[][]
---@param gemCoords Coords current coordinates to search
---@param visited Coords[] list of visited coordinates. Start with "{}" if new match
---@return Coords[] # list of coordinates in the match
function FloodMatch(grid, gemCoords, visited)
	-- mark the current cell as visited
	visited[#visited + 1] = gemCoords
	for _, neighbor in pairs(Neighbors(gemCoords)) do
		if not Contains(visited, neighbor) then
			if grid[neighbor.y][neighbor.x] == grid[gemCoords.y][gemCoords.x] then
				-- do recursion for all non-visited neighbors
				visited = FloodMatch(grid, neighbor, visited)
			end
		end
	end
	return visited
end

-- Calculate the score for a match.
---@param level integer
---@param combo integer
---@param match_size integer
function MatchScore(level, combo, match_size)
	local base_level_points = level * BASE_MATCH_PTS
	local size_bonus = level * (match_size - 3)
	local combo_bonus = min(combo, 7)
	return combo_bonus * (base_level_points + size_bonus)
end

-- do all actions for selecting which gem to swap
---@param grid_cursor Coords | nil # player's grid cursor. May be nil from mouse controls.
---@param mouse_enabled boolean # whether or not the mouse is enabled
---@return Coords | nil # which gem was chosen to swap with the player's cursor
function SelectSwapping(grid_cursor, mouse_enabled)
	---@type Coords | nil
	if grid_cursor == nil then
		return nil
	end
	local swapping_gem = nil
	if mouse_enabled and band(stat(34), 0x1) == 1 then
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
