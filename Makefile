APP_NAME := Guarana
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
MODULE_CACHE_DIR := $(BUILD_DIR)/ModuleCache

.PHONY: all app run clean

all: app

app: $(MACOS_DIR)/$(APP_NAME) $(CONTENTS_DIR)/Info.plist

$(MACOS_DIR)/$(APP_NAME): Sources/Guarana/main.swift
	mkdir -p $(MACOS_DIR) $(MODULE_CACHE_DIR)
	swiftc -O -module-cache-path $(MODULE_CACHE_DIR) -framework AppKit -o $@ $<

$(CONTENTS_DIR)/Info.plist: Info.plist
	mkdir -p $(CONTENTS_DIR)
	cp $< $@

run: app
	open $(APP_DIR)

clean:
	rm -rf $(BUILD_DIR)
