.PHONY: setup test open generate build icons

setup:
	@chmod +x scripts/setup.sh
	@./scripts/setup.sh

icons:
	swift scripts/render-brand-icons.swift "$(CURDIR)"

generate:
	xcodegen generate

test:
	cd BoskePulseCore && swift test

build: setup icons
	xcodebuild -scheme BoskePulse -project BoskePulse.xcodeproj -configuration Debug build CODE_SIGNING_ALLOWED=NO

open:
	open BoskePulse.xcodeproj
