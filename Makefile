SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# xcode-select points at CommandLineTools on this machine; always use full Xcode.
export DEVELOPER_DIR := /Applications/Xcode-beta.app/Contents/Developer

PROJECT := ReverseItApp.xcodeproj
SCHEME := ReverseItApp
DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: build test ui-test lint

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' build | xcbeautify

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -only-testing:ReverseItAppTests test | xcbeautify

ui-test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -only-testing:ReverseItAppUITests test | xcbeautify

lint:
	swiftlint --strict
