# Stratagem: A Nonlinear Match-3 Game for the PICO-8

Stratagem (originally named Gemini) is a match-3 game for the
[PICO-8 fantasy console](https://www.lexaloffle.com/pico-8.php) where you swap
adjacent gems on a grid to gain points. Unlike other popular match-3 games, any
group of gems that directly touch on the grid are cleared, not just ones that
are in the same row or column.

While you can make any move on the board that swaps two touching gems, you can
only make three moves that don't clear groups of gems before the game is over.

## Build Instructions

The included Makefile uses
[`picotool`](https://www.dansanderson.com/projects/picotool/) to assemble and
apply operations to the cartridge parts. Simply run the following code to
download and run Stratagem on your machine (assuming the PICO-8 executable is on
your PATH).

```bash
git clone github.com/vm70/stratagem
cd stratagem
make
```

## Contributing

Contributions are welcome. If you find a bug or would like to request a feature,
please report it through Stratagem's
[issues](https://github.com/vm70/stratagem/issues) page on its GitHub
repository.

Contributors:

- Vincent "VM" Mercator ([@vm70](https://github.com/vm70/)): Lead
  Developer/Artist/Musician
- MattSquare ([@squaremango](https://github.com/squaremango)): Gem Sprite Artist

...and players like you. Thank you!

## Special Thanks

- [Cameron](https://cmrn.io/)
  ([@spriterights](https://www.lexaloffle.com/bbs/?uid=18643),
  [@z6v](https://x.com/z6v)), creator of
  ["Match-3"](https://www.lexaloffle.com/bbs/?pid=42523)
- [@Grumpydev](https://www.lexaloffle.com/bbs/?uid=31046), creator of
  ["Persistent High Score Table Demo"](https://www.lexaloffle.com/bbs/?tid=31901)
- Jason Kapalka & Heather Hazen, original creators of _Bejeweled_
- [Dan Sanderson](https://www.dansanderson.com/), creator of `pico-tool`

## License

> Copyright © 2019-2024 Vincent Mercator
>
> This program is free software: you can redistribute it and/or modify it under
> the terms of the GNU General Public License as published by the Free Software
> Foundation, either version 3 of the License, or (at your option) any later
> version.
>
> This program is distributed in the hope that it will be useful, but WITHOUT
> ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
> FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
>
> You should have received a copy of the GNU General Public License along with
> this program. If not, see <http://www.gnu.org/licenses/>.
