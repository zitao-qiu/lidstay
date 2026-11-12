# LidStay — build and install a menu-bar app that keeps a MacBook running
# with the lid closed, only for the session you ask for.
#
#   make            build LidStay.app into ./build
#   make install    copy it to ~/Applications
#   make run        build and launch
#   make clean      remove build artifacts
#   make uninstall  remove the app (keeps the sudoers rule)

APP      := LidStay
BUNDLEID := io.github.lidstay.app
VERSION  := 1.1.0
BUILD    := build
BUNDLE   := $(BUILD)/$(APP).app
BIN      := $(BUNDLE)/Contents/MacOS/$(APP)
SRC      := $(wildcard Sources/*.swift)
ICON     := Resources/AppIcon.icns
FRAMEWORKS := -framework SwiftUI -framework AppKit -framework IOKit -framework ServiceManagement

.PHONY: all build install run clean uninstall lint

all: build

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	@if [ -f "$(ICON)" ]; then cp "$(ICON)" "$(BUNDLE)/Contents/Resources/AppIcon.icns"; fi
	@echo "Compiling $(APP) $(VERSION)…"
	@swiftc -O -parse-as-library $(SRC) -o "$(BIN)" $(FRAMEWORKS)
	@printf '%s\n' \
	  '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0"><dict>' \
	  '  <key>CFBundleExecutable</key><string>$(APP)</string>' \
	  '  <key>CFBundleIdentifier</key><string>$(BUNDLEID)</string>' \
	  '  <key>CFBundleName</key><string>$(APP)</string>' \
	  '  <key>CFBundleDisplayName</key><string>$(APP)</string>' \
	  '  <key>CFBundleIconFile</key><string>AppIcon</string>' \
	  '  <key>CFBundlePackageType</key><string>APPL</string>' \
	  '  <key>CFBundleShortVersionString</key><string>$(VERSION)</string>' \
	  '  <key>CFBundleVersion</key><string>$(VERSION)</string>' \
	  '  <key>LSMinimumSystemVersion</key><string>13.0</string>' \
	  '  <key>LSUIElement</key><true/>' \
	  '  <key>NSHighResolutionCapable</key><true/>' \
	  '</dict></plist>' > "$(BUNDLE)/Contents/Info.plist"
	@codesign --force --deep --sign - "$(BUNDLE)" 2>/dev/null || true
	@echo "✅ built $(BUNDLE)"

install: build
	@rm -rf "$$HOME/Applications/$(APP).app"
	@mkdir -p "$$HOME/Applications"
	@cp -R "$(BUNDLE)" "$$HOME/Applications/"
	@echo "✅ installed $$HOME/Applications/$(APP).app"

run: build
	@open "$(BUNDLE)"

lint:
	@swiftc -parse-as-library -typecheck $(SRC) $(FRAMEWORKS) && echo "✅ typecheck ok"

clean:
	@rm -rf "$(BUILD)"
	@echo "cleaned"

uninstall:
	@pkill -x $(APP) 2>/dev/null || true
	@rm -rf "$$HOME/Applications/$(APP).app"
	@echo "removed $$HOME/Applications/$(APP).app"
	@echo "note: the sudoers rule and ~/.config/lidstay are left in place"
