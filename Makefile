SHELL = /bin/sh
.SUFFIXES:
.SUFFIXES: .lua .p8

build-cart:
	p8tool build stratagem.p8 \
		--lua stratagem.lua \
		--gfx stratagem-art.p8 \
		--map stratagem-art.p8 \
		--sfx stratagem-art.p8 \
		--music stratagem-art.p8

run-cart: build-cart
	pico8 -run stratagem.p8
