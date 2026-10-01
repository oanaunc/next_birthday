import SwiftUI
import SwiftData

struct CelebrationStudioView: View {
    @Binding var showingAdd: Bool
    @Query private var people: [Person]
    @Environment(SubscriptionStore.self) private var store
    private var upcoming: [Person] { people.sorted { $0.nextBirthday < $1.nextBirthday } }
    private var due: [Person] {
        people.filter { person in
            guard person.connectionCadence > 0 else { return false }
            let elapsed = Calendar.current.dateComponents([.day], from: person.lastConnectionDate ?? person.createdAt, to: Date()).day ?? 0
            return elapsed >= person.connectionCadence
        }.sorted { ($0.lastConnectionDate ?? $0.createdAt) < ($1.lastConnectionDate ?? $1.createdAt) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day()).font(.caption.weight(.semibold)).textCase(.uppercase).tracking(2).foregroundStyle(.secondary)
                    Text("Small gestures.\nLasting connections.").font(.system(.largeTitle, design: .serif, weight: .semibold))
                    Text("Your space to remember, plan and show up.").foregroundStyle(.secondary)
                    if let next = upcoming.first {
                        NavigationLink { CelebrationPlanView(person: next) } label: {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack { Label("THE NEXT OCCASION", systemImage: "sun.max").font(.caption.bold()).tracking(1); Spacer() }
                                Text(next.displayFirstName).font(.system(.largeTitle, design: .serif, weight: .bold))
                                Text("\(next.shortDateLabel) · \(next.countdownLabel)").font(.subheadline)
                                Divider().overlay(.white.opacity(0.3))
                                Text(next.celebrationIntent.isEmpty ? "What would make them feel seen?" : next.celebrationIntent).font(.title3)
                                Label("Make a thoughtful plan", systemImage: "arrow.up.right").font(.subheadline.bold())
                            }.padding(24).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.purple, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    } else {
                        ContentUnavailableView("Start with someone you love", systemImage: "person.crop.circle.badge.plus", description: Text("Add their birthday, then plan something personal."))
                        Button("Add your first person") { showingAdd = true }.buttonStyle(.borderedProminent)
                    }
                    if store.isPro && !due.isEmpty {
                        SectionHeader(title: "Time to reconnect", count: due.count)
                        ForEach(due) { person in
                            NavigationLink { CelebrationPlanView(person: person) } label: {
                                HStack { AvatarView(name: person.fullName, initials: person.initials, photoData: person.photoData, size: 44); VStack(alignment: .leading) { Text(person.fullName).font(.headline); Text("A little time together is due").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "arrow.up.right") }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                        }
                    }
                    if !upcoming.isEmpty {
                        SectionHeader(title: "On your horizon", count: upcoming.prefix(5).count)
                        ForEach(Array(upcoming.prefix(5))) { person in
                            NavigationLink { CelebrationPlanView(person: person) } label: {
                                HStack(alignment: .top) {
                                    Text(person.shortDateLabel).font(.caption.bold()).foregroundStyle(Theme.purple).frame(width: 58, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 6) { Text(person.fullName).font(.headline); Text(person.celebrationIntent.isEmpty ? "An open invitation to be thoughtful" : person.celebrationIntent).font(.subheadline).foregroundStyle(.secondary) }
                                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                                }.padding(.vertical, 12)
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Image("CarePicnic").resizable().scaledToFill().frame(height: 180).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("TRY A SMALL GESTURE").font(.caption.bold()).tracking(2).foregroundStyle(Theme.purple)
                            Text("Ask about something they were looking forward to. Remembering the little things can mean more than buying something.").font(.system(.title3, design: .serif))
                            Text("No streaks. No scores. Just people.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { ProPlanView() } label: { Label("Build your connection rhythm with Pro", systemImage: "leaf") }.font(.subheadline)
                }.padding(24)
            }.screenBackground(.upcoming).navigationTitle("Today").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add person") } }
        }
    }
}
