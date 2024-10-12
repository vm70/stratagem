-- Leaderboard elements.

---@type string Allowed initial characters for high scores
ALLOWED_LETTERS = "abcdefghijklmnopqrstuvwxyz0123456789 "

-- equivalent of `string.find` in vanilla Lua's standard library
---@param str string
---@param wantChar string
---@return integer | nil
function StringFind(str, wantChar)
	for idx = 1, #str do
		if str[idx] == wantChar then
			return idx
		end
	end
	return nil
end

-- Initialize the high scores by reading from persistent memory
---@param leaderboard HighScore[]
function LoadLeaderboard(leaderboard)
	for entry_idx = 1, 10 do
		---@type integer[]
		local raw_score_data = {}
		for word = 1, 4 do
			raw_score_data[word] = dget(4 * (entry_idx - 1) + word - 1)
		end
		if raw_score_data[1] == 0 then
			raw_score_data = { 1, 1, 1, (11 - entry_idx) * 100 }
		end
		leaderboard[entry_idx] = DefaultScoreEntry(entry_idx)
	end
end

---@param leaderboard HighScore[]
function ResetLeaderboard(leaderboard)
	for entry_idx = 1, 10 do
		leaderboard[entry_idx] = DefaultScoreEntry(entry_idx)
	end
end

-- Create a default score value for populating / resetting the leaderboard.
---@param entry_idx # leaderboard entry index
---@return HighScore
function DefaultScoreEntry(entry_idx)
	return {
		initials = "aaa",
		shifted_score = lshr((11 - entry_idx) * 100, 16),
	}
end

-- Add the player's new high score to the leaderboard
---@param leaderboard HighScore[]
---@param letter_ids integer[]
function UpdateLeaderboard(leaderboard, letter_ids, shifted_score)
	local first = ALLOWED_LETTERS[letter_ids[1]]
	local second = ALLOWED_LETTERS[letter_ids[2]]
	local third = ALLOWED_LETTERS[letter_ids[3]]
	---@type HighScore
	local new_high_score = { initials = first .. second .. third, shifted_score = shifted_score }
	local placement = FindPlacement(leaderboard, shifted_score)
	if 1 <= placement and placement <= 10 then
		add(leaderboard, new_high_score, placement)
		leaderboard[11] = nil
	end
end

-- Save the leaderboard to the cartridge memory
---@param leaderboard HighScore[]
function SaveLeaderboard(leaderboard)
	for entry_idx, entry in ipairs(leaderboard) do
		local first = StringFind(ALLOWED_LETTERS, entry.initials[1])
		dset(4 * (entry_idx - 1) + 0, first)
		local second = StringFind(ALLOWED_LETTERS, entry.initials[2])
		dset(4 * (entry_idx - 1) + 1, second)
		local third = StringFind(ALLOWED_LETTERS, entry.initials[3])
		dset(4 * (entry_idx - 1) + 2, third)
		dset(4 * (entry_idx - 1) + 3, entry.shifted_score)
	end
end

-- Calculate a score's placement in the leaderboard.
---@param leaderboard HighScore[]
---@param player_score integer
---@return integer | nil # which placement (1-10) if the player got a high score; nil otherwise
function FindPlacement(leaderboard, player_score)
	for entry_idx, entry in ipairs(leaderboard) do
		if player_score > entry.shifted_score then
			return entry_idx
		end
	end
	return nil
end
