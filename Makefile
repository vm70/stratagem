SHELL = /bin/sh
PICO8_PATH := pico8
BUILD_DIR := ./build

.SUFFIXES:
.SUFFIXES: .lua .p8

# Do everything
everything: setup build-cart run-cart

# Set up development environment
setup:
	# Install pico-tool in an isolated Python environment
	/usr/bin/python3 -m venv .venv
	.venv/bin/pip install git+https://github.com/dansanderson/picotool.git

# Build the cart and place results in the 'build' directory
build-cart:
	# Create folder if not exists
	mkdir -p $(BUILD_DIR)
	# Assemble P8 cart
	.venv/bin/p8tool build $(BUILD_DIR)/stratagem.p8 \
		--lua src/main.lua \
		--gfx assets/art.p8 \
		--map assets/art.p8 \
		--sfx assets/sound.p8 \
		--music assets/sound.p8
	# Append label image
	cat assets/label.txt >> $(BUILD_DIR)/stratagem.p8
	# Assemble P8.PNG cart
	$(PICO8_PATH) $(BUILD_DIR)/stratagem.p8 -export $(BUILD_DIR)/stratagem.p8.png
	# Convert back to P8 format
	$(PICO8_PATH) $(BUILD_DIR)/stratagem.p8.png -export $(BUILD_DIR)/stratagem.p8

run-cart: build-cart
	$(PICO8_PATH) -run $(BUILD_DIR)/stratagem.p8
