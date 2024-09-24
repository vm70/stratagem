# Contributing to Stratagem

This file contains important information about contributing to Stratagem.

## Pre-Commit & Linting Tools

This project uses [`pre-commit`](https://pre-commit.com/) to enforce style guide
consistency with `stylua`, `prettier`, and `selene`. Please install it and its
project-related dependencies using the following shell commands before
contributing documentation or Lua code.

```bash
pipx install pre-commit
cargo install stylua --features lua52
cargo install selene
npm install -g prettier
pre-commit install
```

This project also uses [Lua LS](https://luals.github.io) to enforce type
hinting.

## Semantic Versioning

This project uses [semantic versioning](https://semver.org/) for determining
version numbers.

## Directory Structure

Stratagem's cartridge is split across several files in this repository for more
modular version control. See the following table for the location of each
cartridge section.

| Cartridge Part     | Part Header | Project Location   |
| :----------------- | :---------- | :----------------- |
| P8Lua code imports | `__lua__`   | `src/main.p8`      |
| Lua code           | `-->8`      | `src/*.lua`        |
| Sprite sheet       | `__gfx__`   | `assets/art.p8`    |
| Sprite flags       | `__gff__`   | `assets/art.p8`    |
| Cartridge label    | `__label__` | `assets/label.txt` |
| Tile Map           | `__map__`   | `assets/art.p8`    |
| Sound Effects      | `__sfx__`   | `assets/sound.p8`  |
| Music Patterns     | `__music__` | `assets/sound.p8`  |
