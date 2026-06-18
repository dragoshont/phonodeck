.PHONY: generate build test clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project PhonoDeck.xcodeproj -scheme PhonoDeck -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild -project PhonoDeck.xcodeproj -scheme PhonoDeck -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test

clean:
	rm -rf build DerivedData PhonoDeck.xcodeproj
