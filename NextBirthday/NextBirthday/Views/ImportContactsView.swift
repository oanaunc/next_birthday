import SwiftUI
import SwiftData
import Contacts
import UIKit

/// Shows exactly what will be imported before anything is written.
struct ImportContactsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query private var existing: [Person]

    @State private var candidates: [ContactCandidate] = []
    @State private var selected: Set<String> = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var permissionDenied = false
    @State private var hideDuplicates = true

    private var visible: [ContactCandidate] {
        candidates.filter { candidate in
            if hideDuplicates, case .alreadyImported = status(for: candidate) { return false }
            guard !searchText.isEmpty else { return true }
            return candidate.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectableIDs: [String] {
        visible.compactMap { candidate in
            if case .alreadyImported = status(for: candidate) { return nil }
            return candidate.id
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Reading Contacts…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if permissionDenied {
                    permissionView
                } else if candidates.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
            .screenBackground(.importing, intensity: 0.22)
            .navigationTitle("Import from Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !candidates.isEmpty {
                        let allVisibleSelected = !selectableIDs.isEmpty
                            && selectableIDs.allSatisfy(selected.contains)
                        Button(allVisibleSelected ? "Deselect All" : "Select All") {
                            // Only touch what's currently visible, so a search
                            // filter can't silently drop earlier selections.
                            if allVisibleSelected {
                                selected.subtract(selectableIDs)
                            } else {
                                selected.formUnion(selectableIDs)
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !candidates.isEmpty && !permissionDenied {
                    importBar
                }
            }
            .task { await load() }
        }
    }

    // MARK: Views

    private var listView: some View {
        List {
            Section {
                Toggle("Hide already imported", isOn: $hideDuplicates)
                    .font(.footnote)
                    .tint(Theme.purple)
                    .listRowBackground(Color.clear)
            } footer: {
                Text("Only contacts that already have a birthday saved in iOS Contacts are listed.")
                    .font(.caption)
            }

            ForEach(visible) { candidate in
                row(for: candidate)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                    )
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(for candidate: ContactCandidate) -> some View {
        let state = status(for: candidate)
        let isImported: Bool = { if case .alreadyImported = state { return true }; return false }()

        return Button {
            guard !isImported else { return }
            if selected.contains(candidate.id) {
                selected.remove(candidate.id)
            } else {
                selected.insert(candidate.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isImported
                      ? "checkmark.circle.fill"
                      : (selected.contains(candidate.id) ? "checkmark.circle.fill" : "circle"))
                    .font(.title3)
                    .foregroundStyle(isImported ? Color.secondary
                                     : (selected.contains(candidate.id) ? Theme.purple : .secondary))

                AvatarView(name: candidate.fullName,
                           initials: candidate.initials,
                           photoData: candidate.photoData,
                           size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.fullName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(candidate.dateLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        switch state {
                        case .alreadyImported:
                            Badge(text: "Imported", tint: .secondary)
                        case .possibleDuplicate(let name):
                            Badge(text: "Possible duplicate of \(name)", tint: Theme.peach)
                        case .new:
                            EmptyView()
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .opacity(isImported ? 0.5 : 1)
        }
        .buttonStyle(.plain)
    }

    private var importBar: some View {
        VStack(spacing: 8) {
            Button {
                performImport()
            } label: {
                Text(selected.isEmpty
                     ? "Select birthdays to import"
                     : "Import \(selected.count) Birthday\(selected.count == 1 ? "" : "s")")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.purple)
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var permissionView: some View {
        ContentUnavailableView {
            Label("Contacts access is off", systemImage: "lock.fill")
        } description: {
            Text("Next Birthday needs permission to read the birthdays saved in your Contacts. Nothing leaves your iPhone.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No birthdays in Contacts", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            Text("None of your contacts have a birthday saved yet. You can add people manually instead.")
        }
    }

    // MARK: Logic

    private func status(for candidate: ContactCandidate) -> ImportStatus {
        ContactsImporter.status(for: candidate, existing: existing)
    }

    @MainActor
    private func load() async {
        isLoading = true
        let granted: Bool
        switch ContactsImporter.authorizationStatus {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = await ContactsImporter.requestAccess()
        default:
            granted = false
        }

        guard granted else {
            permissionDenied = true
            isLoading = false
            return
        }

        candidates = await ContactsImporter.fetchCandidates()
        // Preselect everything that isn't already in the app.
        selected = Set(candidates.compactMap { candidate in
            if case .new = ContactsImporter.status(for: candidate, existing: existing) {
                return candidate.id
            }
            return nil
        })
        isLoading = false
    }

    @MainActor
    private func performImport() {
        let chosen = candidates.filter { selected.contains($0.id) }
        for candidate in chosen {
            let person = ContactsImporter.makePerson(from: candidate, relationship: nil)
            context.insert(person)
        }
        try? context.save()
        settings.lastContactsCheck = Date()
        dismiss()
    }
}

struct Badge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
    }
}
