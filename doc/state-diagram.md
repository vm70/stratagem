# State Diagram Notes

Here is the current implementation of Stratagem's state diagram.

```mermaid
stateDiagram-v2

  [*] --> Menus: cartridge initialized?

  state Menus {
    [*] --> title_screen: cartridge initialized
    [*] --> high_scores: game finished
    title_screen --> credits: view credits
    title_screen --> high_scores: view leaderboard
    title_screen --> [*]: start game

    credits --> title_screen: go back

    high_scores --> title_screen: go back
  }

  Menus --> Gameplay: start game
  Gameplay --> Menus: Game over

  state Gameplay {
    [*] --> game_init: start game

    game_init --> prepare_grid: game done initializing
    prepare_grid --> init_level_transition: grid is ready
    init_level_transition --> game_idle: init animation finished

    game_idle --> Swapping: swap gems
    Swapping --> game_idle: swap canceled
    Swapping --> Matching: swap complete
    Matching --> game_idle: no more holes, no more matches
    game_idle --> LevelUp: player reached level threshold
    LevelUp --> prepare_grid
    game_idle --> GameOver: no more chances
    GameOver --> [*]

    state Swapping {
      state swapping_choice <<choice>>
      [*] --> swapping_choice
      swapping_choice --> swap_select_mouse_held: mouse controls, mouse held?
      swapping_choice --> swap_transition: mouse controls, D-pad pressed?
      swapping_choice --> swap_select: joystick controls, X/O pressed?
      swap_select_mouse_held --> swap_select: mouse released
      swap_select_mouse_held --> swap_transition: mouse moved outside cursor gem
      swap_select --> [*]: cancel swapping
      swap_select --> swap_transition: chose gem to swap
      swap_transition --> [*]: swap complete
    }

    state Matching {
      [*] --> player_matching
      player_matching --> show_match_points: grid contains match
      player_matching --> fill_grid: grid contains no match
      show_match_points --> player_matching: done showing match
      fill_grid --> fill_grid_transition: grid filling successful?
      fill_grid --> combo_check: grid has no holes
      fill_grid_transition --> fill_grid: gem dropping animation finished?
      combo_check --> show_match_points: grid contains matches?
      combo_check --> [*]: grid contains no matches?
    }

    state LevelUp {
      [*] --> level_up_transition
      level_up_transition --> level_up: level-up animation finished?
      level_up --> [*]
    }

    state GameOver {
      [*] --> game_over_transition
      game_over_transition --> game_over: game-over animation finished?
      game_over --> enter_high_score: player got a high score?
      game_over --> [*]: player didn't get a high score?
      enter_high_score --> [*]: player done entering their initials?
    }
  }
```
