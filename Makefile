.PHONY: all clean build release app sign notarize dmg run

# Configuration for code signing and notarization
# Override these on the command line or set as environment variables
DEVELOPER_ID ?= Developer ID Application: Your Name (TEAMID)
APPLE_ID ?= your@email.com
TEAM_ID ?= YOURTEAMID
# Create an app-specific password at appleid.apple.com and store in keychain:
#   xcrun notarytool store-credentials "notarytool-profile" --apple-id "your@email.com" --team-id "TEAMID"
NOTARYTOOL_PROFILE ?= notarytool-profile

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

# Code sign the app with Developer ID (required for notarization)
sign: app
	@echo "Code signing unpkg.app..."
	codesign --force --options runtime --sign "$(DEVELOPER_ID)" unpkg.app
	@echo "Verifying signature..."
	codesign --verify --verbose unpkg.app
	@echo "Code signing complete"

# Notarize the app with Apple
notarize: sign
	@echo "Creating zip for notarization..."
	ditto -c -k --keepParent unpkg.app unpkg-notarize.zip
	@echo "Submitting to Apple for notarization (this may take a few minutes)..."
	xcrun notarytool submit unpkg-notarize.zip --keychain-profile "$(NOTARYTOOL_PROFILE)" --wait
	@echo "Stapling notarization ticket to app..."
	xcrun stapler staple unpkg.app
	@rm -f unpkg-notarize.zip
	@echo "Notarization complete"

# Create DMG for distribution (unsigned)
dmg: app
	@echo "Creating DMG..."
	@rm -rf unpkg-dmg-temp
	@mkdir -p unpkg-dmg-temp
	@cp -r unpkg.app unpkg-dmg-temp/
	@cp "End-user Read Me.rtf" unpkg-dmg-temp/
	hdiutil create -volname "unpkg" -srcfolder unpkg-dmg-temp -ov -format UDZO unpkg.dmg
	@rm -rf unpkg-dmg-temp
	@echo "DMG created: unpkg.dmg"

# Create signed and notarized DMG for distribution
dmg-release: notarize
	@echo "Creating release DMG..."
	@rm -rf unpkg-dmg-temp
	@mkdir -p unpkg-dmg-temp
	@cp -r unpkg.app unpkg-dmg-temp/
	@cp "End-user Read Me.rtf" unpkg-dmg-temp/
	hdiutil create -volname "unpkg" -srcfolder unpkg-dmg-temp -ov -format UDZO unpkg.dmg
	@rm -rf unpkg-dmg-temp
	codesign --force --sign "$(DEVELOPER_ID)" unpkg.dmg
	@echo "Release DMG created: unpkg.dmg"

# Run the app
run: build
	.build/debug/unpkg

# Show help
help:
	@echo "Available targets:"
	@echo "  make build       - Build debug version"
	@echo "  make release     - Build release version (universal binary)"
	@echo "  make app         - Create macOS app bundle"
	@echo "  make sign        - Code sign the app with Developer ID"
	@echo "  make notarize    - Notarize the app with Apple"
	@echo "  make dmg         - Create distribution DMG (unsigned)"
	@echo "  make dmg-release - Create signed and notarized DMG"
	@echo "  make run         - Build and run debug version"
	@echo "  make clean       - Remove build artifacts"
	@echo "  make help        - Show this help"
	@echo ""
	@echo "Before signing/notarizing, set up credentials:"
	@echo "  1. Get your Developer ID: security find-identity -v -p codesigning"
	@echo "  2. Store notarytool credentials:"
	@echo "     xcrun notarytool store-credentials \"notarytool-profile\" \\"
	@echo "       --apple-id \"your@email.com\" --team-id \"TEAMID\""
	@echo ""
	@echo "Then run: make dmg-release DEVELOPER_ID=\"Developer ID Application: Name (TEAMID)\""
