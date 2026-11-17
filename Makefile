APP_NAME := Guarana
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
MODULE_CACHE_DIR := $(BUILD_DIR)/ModuleCache

MIN_MACOS := 13.0
ARCHS ?= arm64 x86_64
# "-" is an ad-hoc signature; pass a "Developer ID Application: ..." identity for distribution.
CODESIGN_IDENTITY ?= -
VERSION ?=

SOURCES := Sources/Guarana/main.swift
ARCH_BINARIES := $(foreach arch,$(ARCHS),$(BUILD_DIR)/$(arch)/$(APP_NAME))
ZIP := $(BUILD_DIR)/$(APP_NAME).zip

.PHONY: all app sign dist icon run clean

all: app

app: $(MACOS_DIR)/$(APP_NAME) $(CONTENTS_DIR)/Info.plist $(RESOURCES_DIR)/AppIcon.icns

$(BUILD_DIR)/%/$(APP_NAME): $(SOURCES)
	mkdir -p $(@D) $(MODULE_CACHE_DIR)
	swiftc -O -target $*-apple-macos$(MIN_MACOS) -module-cache-path $(MODULE_CACHE_DIR) \
		-framework AppKit -o $@ $^

$(MACOS_DIR)/$(APP_NAME): $(ARCH_BINARIES)
	mkdir -p $(@D)
	lipo -create -output $@ $^

$(CONTENTS_DIR)/Info.plist: Info.plist
	mkdir -p $(@D)
	cp $< $@
ifneq ($(VERSION),)
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $@
endif

$(RESOURCES_DIR)/AppIcon.icns: Resources/AppIcon.icns
	mkdir -p $(@D)
	cp $< $@

# Regenerate Resources/AppIcon.{icns,png} from scripts/generate-icon.swift.
icon:
	swift scripts/generate-icon.swift Resources

sign: app
	codesign --force --options runtime --timestamp$(if $(filter -,$(CODESIGN_IDENTITY)),=none,) \
		--sign "$(CODESIGN_IDENTITY)" $(APP_DIR)
	codesign --verify --strict --verbose=2 $(APP_DIR)

dist: sign
	rm -f $(ZIP)
	ditto -c -k --norsrc --noextattr --keepParent $(APP_DIR) $(ZIP)

run: app
	open $(APP_DIR)

clean:
	rm -rf $(BUILD_DIR)
