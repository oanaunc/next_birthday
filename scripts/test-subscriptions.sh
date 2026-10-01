#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild test \
  -project Tests/StoreKit/NextBirthdayProTests.xcodeproj \
  -scheme NextBirthdayProTests \
  -destination "${1:-platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5}" \
  -derivedDataPath /tmp/NextBirthdayProTests \
  -parallel-testing-enabled NO
