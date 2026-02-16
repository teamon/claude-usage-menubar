APP_NAME = ClaudeUsageBar
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

.PHONY: build bundle clean run

build:
	swift build -c release

bundle: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist

run: bundle
	open $(APP_BUNDLE)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
