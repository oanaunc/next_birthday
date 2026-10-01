#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d -t nextbirthday-migration)
trap 'rm -rf "$work"' EXIT
git show 0cb8e8e4a7276adeb663be8d77c57911dfbccc63:NextBirthday/NextBirthday/Models/Person.swift > "$work/OldPerson.swift"
cat > "$work/Writer.swift" <<'SWIFT'
import Foundation
import SwiftData
@main struct Writer {
 @MainActor static func main() throws {
  let schema = Schema([Person.self, GiftIdea.self, GiftRecord.self])
  let config = ModelConfiguration(schema: schema, url: URL(fileURLWithPath: CommandLine.arguments[1]))
  let store = try ModelContainer(for: schema, configurations: [config])
  let person = Person(firstName: "Existing", birthMonth: 10, birthDay: 2, notes: "Keep this note")
  store.mainContext.insert(person)
  store.mainContext.insert(GiftIdea(title: "An old idea", person: person))
  try store.mainContext.save()
 }
}
SWIFT
cat > "$work/Reader.swift" <<'SWIFT'
import Foundation
import SwiftData
@main struct Reader {
 @MainActor static func main() throws {
  let schema = Schema([Person.self, GiftIdea.self, GiftRecord.self])
  let config = ModelConfiguration(schema: schema, url: URL(fileURLWithPath: CommandLine.arguments[1]))
  let store = try ModelContainer(for: schema, configurations: [config])
  let people = try store.mainContext.fetch(FetchDescriptor<Person>())
  precondition(people.count == 1)
  let person = people[0]
  precondition(person.firstName == "Existing" && person.notes == "Keep this note")
  precondition(person.celebrationChecklist.isEmpty && person.connectionJournal.isEmpty && person.connectionCadence == 0)
  precondition(person.giftIdeas?.first?.title == "An old idea")
  person.celebrationIntent = "A new plan"; try store.mainContext.save()
  print("PASS: version-1 persistent SwiftData store migrates with people, notes and gifts preserved")
 }
}
SWIFT
common=(NextBirthday/NextBirthday/Models/Relationship.swift NextBirthday/NextBirthday/Core/Theme.swift NextBirthday/Shared/BirthdayMath.swift)
xcrun swiftc -parse-as-library -target arm64-apple-macos14.0 "$work/OldPerson.swift" "${common[@]}" "$work/Writer.swift" -o "$work/writer"
xcrun swiftc -parse-as-library -target arm64-apple-macos14.0 NextBirthday/NextBirthday/Models/Person.swift "${common[@]}" "$work/Reader.swift" -o "$work/reader"
"$work/writer" "$work/data.store"
"$work/reader" "$work/data.store"
