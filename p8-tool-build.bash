#!/usr/bin/env bash

p8tool build stratagem.p8 \
	--lua stratagem.lua \
	--gfx gemini.p8 \
	--empty-map \
	--empty-sfx \
	--empty-music

pico8 stratagem.p8
