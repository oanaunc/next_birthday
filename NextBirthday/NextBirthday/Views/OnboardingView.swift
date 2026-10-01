import SwiftUI
import SwiftData

/// Two short screens. No tutorial, no account.
struct OnboardingView: View {

    @Environment(AppSettings.self) private var settings
    @State private var page: Int
    @State private var showingImport = false
    @State private var showingAdd = false

    init(initialPage: Int = 0) {
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        ZStack {
            ScreenBackground(art: .onboarding, intensity: 0.55, blur: 8)

            TabView(selection: $page) {
                welcome.tag(0)
                start.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        }
        .sheet(isPresented: $showingImport, onDismiss: finish) {
            ImportContactsView()
        }
        .sheet(isPresented: $showingAdd, onDismiss: finish) {
            AddEditPersonView(person: nil)
        }
    }

    // MARK: Page 1

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("CareGestures")
                .resizable()
                .scaledToFit()
                .frame(width: 210, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Theme.deepInk.opacity(0.2), radius: 24, y: 12)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.purple)
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: 10, y: -8)
                }

            VStack(spacing: 10) {
                Text("Next Birthday")
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.serif)
                    .foregroundStyle(Theme.deepInk)
                Text("Make people feel remembered.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "bell.badge.fill", tint: Theme.purple,
                           title: "From date to thoughtful plan",
                           subtitle: "Plan a gesture, set a budget, make it happen.")
                FeatureRow(icon: "heart.fill", tint: Theme.rose,
                           title: "A journal of showing up",
                           subtitle: "Remember time together, not just birthdays.")
                FeatureRow(icon: "lock.fill", tint: Theme.blue,
                           title: "Private by design",
                           subtitle: "Your personal notes stay on your iPhone.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 8)

            Spacer()

            Button {
                withAnimation { page = 1 }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.purple)
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: Page 2

    private var start: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "birthday.cake.fill")
                .font(.system(size: 56, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.purple, Theme.pink)
                .padding(26)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Theme.purple.opacity(0.14), radius: 20, y: 10)

            Text("How do you want to start?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.deepInk)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    showingImport = true
                } label: {
                    Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.purple)

                Button {
                    showingAdd = true
                } label: {
                    Label("Add a Birthday", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Theme.purple)

                Button("I'll do this later") { finish() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)

            Text("Your data stays on your iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Spacer()
            Spacer()
        }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
    }
}

struct FeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.16)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 32)
    }
}
