.PHONY: generate build test qa-status qa-evidence release-preflight package-local clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project PhonoDeck.xcodeproj -scheme PhonoDeck -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild -project PhonoDeck.xcodeproj -scheme PhonoDeck -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test

qa-status:
	python3 scripts/qa-status.py

qa-evidence:
	python3 scripts/qa-evidence-status.py > docs/qa/production-p0-evidence-closure-report.md

release-preflight:
	bash scripts/release-preflight.sh

package-local:
	bash scripts/package-local.sh

clean:
	rm -rf build DerivedData PhonoDeck.xcodeproj
