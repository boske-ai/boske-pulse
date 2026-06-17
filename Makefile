.PHONY: setup test open generate build

setup:
	@chmod +x scripts/setup.sh
	@./scripts/setup.sh

generate:
	xcodegen generate

test:
	cd BoskePulseCore && swift test

build: setup
	xcodebuild -scheme BoskePulse -project BoskePulse.xcodeproj -configuration Debug build CODE_SIGNING_ALLOWED=NO

open:
	open BoskePulse.xcodeproj
