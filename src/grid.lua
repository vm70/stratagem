--- swap the two gems (done by the player)
---@param grid integer[][]
---@param gem1 Coords
---@param gem2 Coords
function SwapGems(grid, gem1, gem2)
	local temp = grid[gem1.y][gem1.x]
	grid[gem1.y][gem1.x] = grid[gem2.y][gem2.x]
	grid[gem2.y][gem2.x] = temp
end
