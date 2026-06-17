.PHONY: setup test open generate

setup:
	@chmod +x scripts/setup.sh
	@./scripts/setup.sh

generate:
	xcodegen generate

test:
	cd BoskePulseCore && swift test

open:
	open BoskePulse.xcodeproj
