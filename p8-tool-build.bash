#!/usr/bin/env bash

p8tool build stratagem.p8 \
	--lua stratagem.lua \
	--gfx stratagem.misc.p8 \
	--map stratagem.misc.p8 \
	--empty-sfx \
	--empty-music

pico8 stratagem.p8
