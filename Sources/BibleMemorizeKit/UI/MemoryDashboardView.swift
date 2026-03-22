import SwiftUI

public struct MemoryDashboardView: View {
    @State private var viewModel: DashboardViewModel

    @MainActor
    public init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    @MainActor
    public init() {
        _viewModel = State(initialValue: DashboardViewModel())
    }

    public var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        statsSection
                        dueSection
                        upcomingSection
                    }
                    .padding(20)
                }
                .navigationTitle("Bible Memorize")
            }
            .tabItem {
                Label("Review", systemImage: "book.closed")
            }

            NavigationStack {
                SettingsView(store: viewModel.store)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            HStack(spacing: 12) {
                StatCard(title: "Due", value: "\(viewModel.dueCount)")
                StatCard(title: "Solid", value: "\(viewModel.streakEstimate)")
                StatCard(title: "Progress", value: "\(Int(viewModel.reviewCompletion * 100))%")
            }

            Button("Start Review Session") {
                viewModel.store.startSession()
            }
            .buttonStyle(.borderedProminent)

            if let prompt = viewModel.store.todaysSession?.currentPrompt {
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt.reference)
                        .font(.headline)
                    Text(prompt.maskedWords.joined(separator: " "))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var dueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Due Now")
                .font(.headline)

            ForEach(viewModel.store.dueCards) { card in
                VerseRow(card: card, translation: viewModel.store.selectedTranslation)
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.headline)

            ForEach(viewModel.store.upcomingCards) { card in
                VerseRow(card: card, translation: viewModel.store.selectedTranslation)
            }
        }
    }
}

private struct SettingsView: View {
    @Bindable var store: BibleMemorizeStore

    var body: some View {
        Form {
            Section("Bible") {
                Picker("Version", selection: $store.selectedTranslation) {
                    ForEach(Translation.allCases) { translation in
                        Text(translation.rawValue).tag(translation)
                    }
                }
                .pickerStyle(.menu)

                Text("All verses in the app follow the selected Bible version.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct VerseRow: View {
    let card: MemorizationCard
    let translation: Translation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.verse.reference.formatted)
                .font(.headline)
            Text(card.verse.text(for: translation))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("Translation: \(translation.rawValue)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
