import SwiftUI
import StoreKit

struct ProPlanView: View {
    @Environment(SubscriptionStore.self) private var store
    @State private var manage = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image("CareRhythm").resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 12))
                Text("More intention.\nAll year long.").font(.largeTitle.bold()).fontDesign(.serif)
                Text("NEXT BIRTHDAY PRO").font(.caption.weight(.bold)).tracking(3).foregroundStyle(Theme.purple)
                Text("A private planning companion for the people you care about.").foregroundStyle(.secondary)
                FeatureRow(icon: "checklist", tint: Theme.purple, title: "Personal celebration checklists", subtitle: "Build and track the steps behind every gesture.")
                FeatureRow(icon: "arrow.triangle.2.circlepath", tint: Theme.purple, title: "Your connection rhythm", subtitle: "Choose a cadence and see who is due a catch-up on Today.")
                Text("Free includes unlimited birthdays, reminders, gift ideas, celebration intentions, budgets, connection journaling and backups. Your saved plans remain readable if Pro ends.").font(.footnote).foregroundStyle(.secondary)
                if store.isPro {
                    Label("Pro is active", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.purple)
                    Button("Manage subscription") { manage = true }.buttonStyle(.bordered)
                } else {
                    ForEach(store.products, id: \.id) { product in
                        Button { Task { await store.purchase(product) } } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(product.displayName).font(.headline)
                                    Text(product.id.hasSuffix("yearly") ? "Billed yearly · auto-renews" : "Billed monthly · auto-renews").font(.caption)
                                }
                                Spacer()
                                Text(product.displayPrice + (product.id.hasSuffix("yearly") ? "/year" : "/month")).font(.headline)
                            }.padding(12)
                        }.buttonStyle(.borderedProminent).disabled(store.isBusy)
                    }
                    if store.products.isEmpty {
                        Button("Reload plans") { Task { await store.loadProducts() } }.buttonStyle(.bordered)
                    }
                }
                if store.isBusy { ProgressView() }
                if let message = store.message { Text(message).font(.footnote).accessibilityIdentifier("subscriptionMessage") }
                Button("Restore purchases") { Task { await store.restore() } }.disabled(store.isBusy)
                Text("Payment is charged to your Apple Account. Subscriptions automatically renew unless cancelled at least 24 hours before the period ends. Manage or cancel in Apple Account settings.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Link("Privacy", destination: URL(string: "https://oanarinaldi.com/nextbirthdayprivacy.html")!)
                    Spacer()
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }.font(.footnote)
            }.padding(24)
        }.screenBackground(.settings).navigationTitle("Pro").navigationBarTitleDisplayMode(.inline)
            .manageSubscriptionsSheet(isPresented: $manage)
            .task { await store.loadProducts() }
    }
}
