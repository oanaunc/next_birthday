import Foundation
import SwiftData

@main struct BackupRoundTrip {
    @MainActor static func main() throws {
        let schema = Schema([Person.self, GiftIdea.self, GiftRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let source = try ModelContainer(for: schema, configurations: [config])
        let person = Person(firstName: "Ana", birthMonth: 2, birthDay: 29)
        person.celebrationIntent = "A walk by the sea"
        person.celebrationBudget = 50
        person.celebrationChecklist = ["Pack a picnic"]
        person.completedCelebrationSteps = ["Pack a picnic"]
        person.connectionCadence = 14
        person.lastConnectionDate = Date(timeIntervalSince1970: 1700000000)
        person.connectionJournal = ["Shared a coffee"]
        source.mainContext.insert(person)
        try source.mainContext.save()
        let data = BackupService.exportJSON(from: [person])!
        let target = try ModelContainer(for: schema, configurations: [config])
        guard case .success(1, 0) = BackupService.importJSON(data, into: target.mainContext, existing: []) else { fatalError("Import failed") }
        let restored = try target.mainContext.fetch(FetchDescriptor<Person>())[0]
        precondition(restored.celebrationIntent == person.celebrationIntent)
        precondition(restored.celebrationBudget == 50)
        precondition(restored.celebrationChecklist == person.celebrationChecklist)
        precondition(restored.completedCelebrationSteps == person.completedCelebrationSteps)
        precondition(restored.connectionCadence == 14)
        precondition(restored.lastConnectionDate == person.lastConnectionDate)
        precondition(restored.connectionJournal == person.connectionJournal)
        guard case .success(0, 1) = BackupService.importJSON(data, into: target.mainContext, existing: [restored]) else { fatalError("Duplicate imported") }
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["version"] = 1
        var entries = json["people"] as! [[String: Any]]
        for key in ["celebrationIntent", "celebrationBudget", "celebrationChecklist", "completedCelebrationSteps", "connectionCadence", "lastConnectionDate", "connectionJournal"] { entries[0].removeValue(forKey: key) }
        entries[0]["firstName"] = "Legacy"
        json["people"] = entries
        let legacy = try JSONSerialization.data(withJSONObject: json)
        guard case .success(1, 0) = BackupService.importJSON(legacy, into: target.mainContext, existing: [restored]) else { fatalError("Legacy backup incompatible") }
        let old = try target.mainContext.fetch(FetchDescriptor<Person>()).first { $0.firstName == "Legacy" }!
        precondition(old.celebrationChecklist.isEmpty && old.connectionCadence == 0)
        guard case .failure = BackupService.importJSON(Data("invalid".utf8), into: target.mainContext, existing: []) else { fatalError("Invalid JSON accepted") }
        print("PASS: planning and journal round trip, duplicate detection, v1 backward compatibility, malformed backup rejection")
    }
}
