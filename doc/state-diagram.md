# State Diagram

Here is the current implementation of Stratagem's state diagram.

```mermaid
stateDiagram-v2
  [*] --> title_screen: cartridge initialized?

  title_screen --> credits: player wants credits?
  title_screen --> high_scores: player wants high scores?
  title_screen --> game_init: player wants to play game?

  credits --> title_screen: player wants to go back to title?

  game_init --> prepare_grid: game is done initializing?

  prepare_grid --> init_level_transition: game is ready for player?

  init_level_transition --> game_idle: level init animation finished?

  game_idle --> swap_select: player wants to swap gems?
  game_idle --> level_up_transition: player reached level score threshold?
  game_idle --> game_over_transition: player has no more chances?

  swap_select --> game_idle: player doesn't want to swap gems?
  swap_select --> swap_transition: player chose to match gems?

  swap_transition --> player_matching: swap animation finished?

  player_matching --> show_match_points: grid contains match?
  player_matching --> fill_grid: grid contains no match?

  show_match_points --> player_matching: done showing match points?

  fill_grid --> fill_grid_transition: grid filling was successful?
  fill_grid --> combo_check: grid contains no holes?

  fill_grid_transition --> fill_grid: gem dropping animation finished?

  combo_check --> show_match_points: grid contains matches?
  combo_check --> game_idle: grid contains no matches?

  level_up_transition --> level_up: level-up animation finished?

  level_up --> prepare_grid: player and grid ready for next level?

  game_over_transition --> game_over: game-over animation finished?

  game_over --> enter_high_score: player got a high score?
  game_over --> high_scores: player didn't get a high score?

  enter_high_score --> high_scores: player done entering their initials?

  high_scores --> title_screen: player wants to go back to title?
```
