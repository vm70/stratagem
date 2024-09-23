SHELL = /bin/sh
PICO8_PATH := pico8
BUILD_DIR := ./build
PYTHON_VENV := ./.venv

.SUFFIXES:
.SUFFIXES: .lua .p8

stratagem_major = $(shell grep --color=never -o 'major.*=.*,' src/main.lua | grep --color=never -o '[0-9]')
stratagem_minor = $(shell grep --color=never -o 'minor.*=.*,' src/main.lua | grep --color=never -o '[0-9]')
stratagem_patch = $(shell grep --color=never -o 'patch.*=.*,' src/main.lua | grep --color=never -o '[0-9]')
stratagem_version = v$(stratagem_major).$(stratagem_minor).$(stratagem_patch)

p8_file = $(BUILD_DIR)/stratagem-$(stratagem_version).p8
p8png_file = $(BUILD_DIR)/stratagem-$(stratagem_version).p8.png
bin_folder = $(BUILD_DIR)/stratagem-$(stratagem_version).bin

# Do everything
all: setup build-cart run-cart

# Set up development environment
setup:
	# Install pico-tool in an isolated Python environment
	/usr/bin/python3 -m venv $(PYTHON_VENV)
	$(PYTHON_VENV)/bin/pip install git+https://github.com/dansanderson/picotool.git

# Build the cart and place results in the 'build' directory
build-cart:
	echo "Building Stratagem $(stratagem_version)"
	# Create folder if not exists
	mkdir -p $(BUILD_DIR)
	# Assemble P8 cart
	$(PYTHON_VENV)/bin/p8tool build $(p8_file) \
		--lua src/main.p8 \
		--gfx assets/art.p8 \
		--map assets/art.p8 \
		--sfx assets/sound.p8 \
		--music assets/sound.p8

# Use the PICO-8 executable itself to prepare the cart for publishing
prepare-cart: build-cart
ifndef PICO8_PATH
	$(error "PICO-8 is not available on your PATH.")
endif
	# Append label image
	cat assets/label.txt >> $(p8_file)
	# Assemble P8.PNG cart
	$(PICO8_PATH) $(p8_file) -export $(p8png_file)
	# Convert back to P8 format
	$(PICO8_PATH) $(p8png_file) -export $(p8_file)
	# Assemble ZIP file
	zip $(BUILD_DIR)/stratagem-$(stratagem_version).zip \
		README.md \
		CONTRIBUTING.md \
		LICENSE \
		$(p8_file) \
		$(p8png_file)
	# Assemble binary application
	$(PICO8_PATH) $(p8png_file) -export $(bin_folder)

run-cart: build-cart prepare-cart
	$(PICO8_PATH) -run $(p8_file)

clean:
	rm -rf $(BUILD_DIR)
