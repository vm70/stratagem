---@type string Allowed initial characters for high scores
ALLOWED_LETTERS = "abcdefghijklmnopqrstuvwxyz0123456789 "

--- equivalent of `string.find` in vanilla Lua's standard library
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

--- Initialize the high scores by reading from persistent memory
---@param leaderboard HighScore[]
---@param version Version
function LoadLeaderboard(leaderboard, version)
	cartdata("vm70_stratagem_v" .. version.major .. "_" .. version.minor .. "_" .. version.patch)
	for score_idx = 1, 10 do
		---@type integer[]
		local raw_score_data = {}
		for word = 1, 4 do
			raw_score_data[word] = dget(4 * (score_idx - 1) + word - 1)
		end
		if raw_score_data[1] == 0 then
			raw_score_data = { 1, 1, 1, (11 - score_idx) * 100 }
		end
		leaderboard[score_idx] = {
			initials = ALLOWED_LETTERS[raw_score_data[1]]
				.. ALLOWED_LETTERS[raw_score_data[2]]
				.. ALLOWED_LETTERS[raw_score_data[3]],
			score = raw_score_data[4],
		}
	end
end

---@param leaderboard HighScore[]
function ResetLeaderboard(leaderboard)
	for score_idx = 1, 10 do
		leaderboard[score_idx] = {
			initials = ALLOWED_LETTERS[1] .. ALLOWED_LETTERS[1] .. ALLOWED_LETTERS[1],
			score = (11 - score_idx) * 100,
		}
	end
end

--- Add the player's new high score to the leaderboard
---@param leaderboard HighScore[]
---@param letter_ids integer[]
function UpdateLeaderboard(leaderboard, letter_ids, score)
	local first = ALLOWED_LETTERS[letter_ids[1]]
	local second = ALLOWED_LETTERS[letter_ids[2]]
	local third = ALLOWED_LETTERS[letter_ids[3]]
	---@type HighScore
	local new_high_score = { initials = first .. second .. third, score = score }
	local placement = FindPlacement(leaderboard, score)
	if 1 <= placement and placement <= 10 then
		add(leaderboard, new_high_score, placement)
		leaderboard[11] = nil
	end
end

--- Save the leaderboard to the cartridge memory
---@param leaderboard HighScore[]
function SaveLeaderboard(leaderboard)
	for score_idx, score in ipairs(leaderboard) do
		local first = StringFind(ALLOWED_LETTERS, score.initials[1])
		dset(4 * (score_idx - 1) + 0, first)
		local second = StringFind(ALLOWED_LETTERS, score.initials[2])
		dset(4 * (score_idx - 1) + 1, second)
		local third = StringFind(ALLOWED_LETTERS, score.initials[3])
		dset(4 * (score_idx - 1) + 2, third)
		dset(4 * (score_idx - 1) + 3, score.score)
	end
end

--- Calculate a score's placement in the leaderboard.
---@param leaderboard HighScore[]
---@param player_score integer
---@return integer | nil # which placement (1-10) if the player got a high score; nil otherwise
function FindPlacement(leaderboard, player_score)
	for scoreIdx, score in ipairs(leaderboard) do
		if player_score > score.score then
			return scoreIdx
		end
	end
	return nil
end
