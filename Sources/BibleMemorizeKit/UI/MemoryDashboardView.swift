import SwiftUI
import AVFoundation

public struct MemoryDashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var speaker = VerseSpeaker()

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
        .preferredColorScheme(.dark)
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
                    HStack(alignment: .top) {
                        Text(prompt.reference)
                            .font(.headline)

                        Spacer()

                        Button {
                            speaker.speak(
                                text: prompt.promptText,
                                translation: viewModel.store.selectedTranslation,
                                speedMultiplier: viewModel.store.speechRateMultiplier
                            )
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Speak verse")
                    }
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
                VerseRow(
                    card: card,
                    translation: viewModel.store.selectedTranslation,
                    speaker: speaker,
                    speedMultiplier: viewModel.store.speechRateMultiplier
                )
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.headline)

            ForEach(viewModel.store.upcomingCards) { card in
                VerseRow(
                    card: card,
                    translation: viewModel.store.selectedTranslation,
                    speaker: speaker,
                    speedMultiplier: viewModel.store.speechRateMultiplier
                )
            }
        }
    }
}

private struct SettingsView: View {
    @Bindable var store: BibleMemorizeStore

    var body: some View {
        Form {
            Section("Bible") {
                Picker(
                    "Version",
                    selection: Binding(
                        get: { store.selectedTranslation },
                        set: { store.updateSelectedTranslation($0) }
                    )
                ) {
                    ForEach(Translation.allCases) { translation in
                        Text(translation.rawValue).tag(translation)
                    }
                }
                .pickerStyle(.menu)

                Text("All verses in the app follow the selected Bible version.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Speech Speed") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Speed")
                        Spacer()
                        Text(String(format: "%.1fx", store.speechRateMultiplier))
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $store.speechRateMultiplier,
                        in: 0.1...2.0,
                        step: 0.1
                    )

                    HStack {
                        Text("0.1x")
                        Spacer()
                        Text("1.0x")
                        Spacer()
                        Text("2.0x")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Text("1.0x is normal speed. Lower values speak more slowly, and higher values speak faster.")
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
    let speaker: VerseSpeaker
    let speedMultiplier: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(card.verse.reference.formatted)
                    .font(.headline)

                Spacer()

                Button {
                    speaker.speak(
                        text: card.verse.text(for: translation),
                        translation: translation,
                        speedMultiplier: speedMultiplier
                    )
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Speak verse")
            }
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

@MainActor
private final class VerseSpeaker {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(text: String, translation: Translation, speedMultiplier: Double) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: translation.speechLanguageCode)
        let normalizedMultiplier = min(max(speedMultiplier, 0.1), 2.0)
        let scaledRate = AVSpeechUtteranceDefaultSpeechRate * Float(normalizedMultiplier)
        utterance.rate = min(max(scaledRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        synthesizer.speak(utterance)
    }
}
