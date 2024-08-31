SHELL = /bin/sh
.SUFFIXES:
.SUFFIXES: .lua .p8

build-cart:
	rm -f stratagem.p8
	touch stratagem.p8
	cat src/header.txt >> stratagem.p8
	cat src/main.lua >> stratagem.p8
	sed -n '1,2!p' assets/art.p8 >> stratagem.p8
	sed -n '1,2!p' assets/sound.p8 >> stratagem.p8
	
run-cart: build-cart
	pico8 -run stratagem.p8
