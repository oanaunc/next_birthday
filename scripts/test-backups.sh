#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
binary=$(mktemp -t nextbirthday-tests)
trap 'rm -f "$binary"' EXIT
xcrun swiftc -parse-as-library -target arm64-apple-macos14.0 \
  NextBirthday/NextBirthday/Models/Person.swift \
  NextBirthday/NextBirthday/Models/Relationship.swift \
  NextBirthday/NextBirthday/Core/Theme.swift \
  NextBirthday/Shared/BirthdayMath.swift \
  NextBirthday/NextBirthday/Services/BackupService.swift \
  Tests/BackupRoundTrip.swift -o "$binary"
"$binary"
