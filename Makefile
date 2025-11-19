.PHONY: all clean build release app dmg run

# Default target
all: app

# Clean build artifacts
clean:
	rm -rf .build
	rm -rf unpkg.app
	rm -f unpkg.dmg
	rm -rf unpkg-dmg-temp

# Build debug version
build:
	swift build

# Build release version (universal binary for Intel and Apple Silicon)
release:
	@echo "Building for x86_64..."
	swift build -c release --arch x86_64
	@echo "Building for arm64..."
	swift build -c release --arch arm64
	@echo "Creating universal binary..."
	mkdir -p .build/release
	lipo -create \
		.build/x86_64-apple-macosx/release/unpkg \
		.build/arm64-apple-macosx/release/unpkg \
		-output .build/release/unpkg
	@echo "Universal binary created"

# Create macOS app bundle
app: release
	@echo "Creating app bundle..."
	mkdir -p unpkg.app/Contents/MacOS
	mkdir -p unpkg.app/Contents/Resources
	cp .build/release/unpkg unpkg.app/Contents/MacOS/
	cp Info.plist unpkg.app/Contents/
	cp Assets.xcassets/AppIcon.appiconset/unpkg.icns unpkg.app/Contents/Resources/
	@echo "App bundle created: unpkg.app"

# Create DMG for distribution
dmg: app
	@echo "Creating DMG..."
	@rm -rf unpkg-dmg-temp
	@mkdir -p unpkg-dmg-temp
	@cp -r unpkg.app unpkg-dmg-temp/
	@cp "End-user Read Me.rtf" unpkg-dmg-temp/
	hdiutil create -volname "unpkg" -srcfolder unpkg-dmg-temp -ov -format UDZO unpkg.dmg
	@rm -rf unpkg-dmg-temp
	@echo "DMG created: unpkg.dmg"

# Run the app
run: build
	.build/debug/unpkg

# Show help
help:
	@echo "Available targets:"
	@echo "  make build    - Build debug version"
	@echo "  make release  - Build release version"
	@echo "  make app      - Create macOS app bundle"
	@echo "  make dmg      - Create distribution DMG"
	@echo "  make run      - Build and run debug version"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make help     - Show this help"
