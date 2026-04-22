APP     = Skill Reader
BUNDLE  = $(HOME)/Applications/$(APP).app
SYSTEM  = /Applications/$(APP).app
DISTAPP = dist/$(APP).app
DMG     = dist/$(APP).dmg

.PHONY: app dmg install install-system uninstall run clean

## Build a standalone .app bundle in ./dist
app:
	@bash assemble-app.sh dist

## Build a distributable DMG for drag-and-drop install
dmg:
	@bash build-dmg.sh

## Install to ~/Applications (no sudo needed)
install:
	@bash install.sh "$(HOME)/Applications"

## Install to /Applications (requires sudo)
install-system:
	@sudo bash install.sh "/Applications"

## Run directly without installing
run:
	swift run

## Remove from ~/Applications
uninstall:
	@rm -rf "$(BUNDLE)" && echo "✓ Removed $(BUNDLE)"

## Remove from /Applications
uninstall-system:
	@sudo rm -rf "$(SYSTEM)" && echo "✓ Removed $(SYSTEM)"

clean:
	swift package clean
	@rm -rf dist
