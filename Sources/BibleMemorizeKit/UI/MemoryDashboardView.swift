import SwiftUI
import AVFoundation

public struct MemoryDashboardView: View {
    @State private var viewModel: DashboardViewModel
    @StateObject private var speaker = VerseSpeaker()
    @State private var isShowingAddVerse = false

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
                List {
                    VStack(alignment: .leading, spacing: 20) {
                        statsSection
                    }
                    .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 12, trailing: 20))
                    .listRowBackground(Color.clear)

                    dueSection
                    upcomingSection
                }
                .listStyle(.plain)
                .navigationTitle("Bible Memorize")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingAddVerse = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .overlay(alignment: .topTrailing) {
                                    if viewModel.store.isOpenAIEnabled {
                                        Image(systemName: "sparkles")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.green)
                                            .offset(x: 5, y: -5)
                                    }
                                }
                        }
                    }
                }
                .sheet(isPresented: $isShowingAddVerse) {
                    AddVerseView(store: viewModel.store)
                }
            }
            .tabItem {
                Label("Review", systemImage: "book.closed")
            }

            NavigationStack {
                ProgressView(store: viewModel.store)
            }
            .tabItem {
                Label("Progress", systemImage: "chart.bar.xaxis")
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

            Button(viewModel.store.todaysSession == nil ? "Start Review Session" : "Hide Review Session") {
                viewModel.store.toggleSession()
            }
            .buttonStyle(.borderedProminent)

            if let prompt = viewModel.store.todaysSession?.currentPrompt {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(prompt.reference)
                            .font(.headline)

                        Spacer()

                        controls(for: prompt.cardID, text: prompt.promptText)
                    }
                    Text(prompt.maskedWords.joined(separator: " "))
                        .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            viewModel.store.moveToPreviousSessionPrompt()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.bordered)
                        .disabled(!(viewModel.store.todaysSession?.canMoveToPreviousPrompt ?? false))

                        Spacer()

                        Button {
                            viewModel.store.moveToNextSessionPrompt()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.bordered)
                        .disabled(!(viewModel.store.todaysSession?.canMoveToNextPrompt ?? false))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var dueSection: some View {
        Section {
            ForEach(viewModel.store.dueCards) { card in
                VerseRow(
                    card: card,
                    translation: viewModel.store.selectedTranslation,
                    speaker: speaker,
                    speedMultiplier: viewModel.store.speechRateMultiplier
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.store.deleteVerse(cardID: card.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("Due Now")
                .font(.headline)
        }
    }

    private var upcomingSection: some View {
        Section {
            ForEach(viewModel.store.upcomingCards) { card in
                VerseRow(
                    card: card,
                    translation: viewModel.store.selectedTranslation,
                    speaker: speaker,
                    speedMultiplier: viewModel.store.speechRateMultiplier
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.store.deleteVerse(cardID: card.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("Upcoming")
                .font(.headline)
        }
    }

    @ViewBuilder
    private func controls(for verseID: UUID, text: String) -> some View {
        HStack(spacing: 14) {
            Button {
                speaker.speak(
                    verseID: verseID,
                    text: text,
                    translation: viewModel.store.selectedTranslation,
                    speedMultiplier: viewModel.store.speechRateMultiplier
                )
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Speak verse")

            Button {
                speaker.advanceRepeatMode(for: verseID)
            } label: {
                Image(systemName: "repeat")
                    .font(.headline)
                    .overlay(alignment: .topTrailing) {
                        if let label = speaker.repeatBadge(for: verseID) {
                            Text(label)
                                .font(.caption2.bold())
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .offset(x: 12, y: -8)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Repeat verse")
        }
    }
}

private struct AddVerseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: BibleMemorizeStore

    @State private var selectedTranslation: Translation = .nkjv
    @State private var selectedBook: BibleBook = .john
    @State private var selectedChapter = 1
    @State private var selectedVerseStart = 1
    @State private var selectedVerseEndEnabled = false
    @State private var selectedVerseEnd = 1
    @State private var verseText = ""
    @State private var tagsText = ""
    @State private var difficulty: VerseDifficulty = .medium
    @State private var isFetchingVerseText = false
    @State private var aiLookupMessage: String?

    private var isValid: Bool {
        !verseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var aiLookupSignature: String {
        [
            selectedTranslation.rawValue,
            selectedBook.rawValue,
            String(selectedChapter),
            String(selectedVerseStart),
            selectedVerseEndEnabled ? String(selectedVerseEnd) : ""
        ].joined(separator: "|")
    }

    private var availableChapters: [Int] {
        Array(1...150)
    }

    private var availableVerses: [Int] {
        Array(1...176)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reference") {
                    Picker("Translation", selection: $selectedTranslation) {
                        ForEach(Translation.allCases) { translation in
                            Text(translation.rawValue).tag(translation)
                        }
                    }

                    Picker("Book", selection: $selectedBook) {
                        ForEach(BibleBook.allCases) { book in
                            Text(book.displayName(for: selectedTranslation)).tag(book)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Chapter", selection: $selectedChapter) {
                        ForEach(availableChapters, id: \.self) { chapter in
                            Text("\(chapter)").tag(chapter)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Verse Start", selection: $selectedVerseStart) {
                        ForEach(availableVerses, id: \.self) { verse in
                            Text("\(verse)").tag(verse)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedVerseStart) { _, newValue in
                        if selectedVerseEnd < newValue {
                            selectedVerseEnd = newValue
                        }
                    }

                    Toggle("Use Verse End", isOn: $selectedVerseEndEnabled)

                    if selectedVerseEndEnabled {
                        Picker("Verse End", selection: $selectedVerseEnd) {
                            ForEach(availableVerses.filter { $0 >= selectedVerseStart }, id: \.self) { verse in
                                Text("\(verse)").tag(verse)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Content") {
                    TextField("Tags (comma separated)", text: $tagsText)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(VerseDifficulty.allCases) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }

                    TextField("Verse Text", text: $verseText, axis: .vertical)
                        .lineLimit(5...10)

                    if store.canUseOpenAI {
                        if isFetchingVerseText {
                            SwiftUI.ProgressView()
                        }

                        if let aiLookupMessage {
                            Text(aiLookupMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Verse")
            .task(id: aiLookupSignature) {
                await fetchVerseTextIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveVerse()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            selectedTranslation = store.selectedTranslation
        }
    }

    private func saveVerse() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        store.addVerse(
            reference: BibleReference(
                book: selectedBook.rawValue,
                chapter: selectedChapter,
                verseStart: selectedVerseStart,
                verseEnd: selectedVerseEndEnabled ? selectedVerseEnd : nil
            ),
            translation: selectedTranslation,
            text: verseText.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            difficulty: difficulty
        )

        dismiss()
    }

    private func fetchVerseTextIfNeeded() async {
        guard store.canUseOpenAI else { return }

        isFetchingVerseText = true
        aiLookupMessage = "Fetching verse text with OpenAI..."

        do {
            let text = try await store.fetchVerseTextWithAI(
                request: VerseLookupRequest(
                    translation: selectedTranslation,
                    book: selectedBook.rawValue,
                    chapter: selectedChapter,
                    verseStart: selectedVerseStart,
                    verseEnd: selectedVerseEndEnabled ? selectedVerseEnd : nil
                )
            )
            verseText = text
            aiLookupMessage = "Verse text loaded. You can still edit it."
        } catch {
            aiLookupMessage = "Could not load verse text automatically."
        }

        isFetchingVerseText = false
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

            Section("AI (OpenAI) Mode") {
                Toggle("Enable AI Mode", isOn: Binding(
                    get: { store.isOpenAIEnabled },
                    set: { store.setOpenAIEnabled($0) }
                ))

                SecureField("OpenAI API Key", text: $store.openAIAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(!store.isOpenAIEnabled)

                Button("Validate Key") {
                    Task {
                        await store.validateOpenAIKey()
                    }
                }
                .disabled(!store.isOpenAIEnabled)

                if let status = store.openAIStatusMessage {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(store.openAIValidationState == .valid ? .green : .secondary)
                }
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
    @ObservedObject var speaker: VerseSpeaker
    let speedMultiplier: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(card.verse.reference.formatted(for: translation))
                    .font(.headline)

                Spacer()

                HStack(spacing: 14) {
                    Button {
                        speaker.speak(
                            verseID: card.id,
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

                    Button {
                        speaker.advanceRepeatMode(for: card.id)
                    } label: {
                        Image(systemName: "repeat")
                            .font(.headline)
                            .overlay(alignment: .topTrailing) {
                                if let label = speaker.repeatBadge(for: card.id) {
                                    Text(label)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.blue)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                        .offset(x: 12, y: -8)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Repeat verse")
                }
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
private final class VerseSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private var repeatModes: [UUID: RepeatMode] = [:]

    private let synthesizer = AVSpeechSynthesizer()
    private var activePlayback: ActivePlayback?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        verseID: UUID,
        text: String,
        translation: Translation,
        speedMultiplier: Double
    ) {
        activePlayback = ActivePlayback(
            verseID: verseID,
            text: text,
            translation: translation,
            speedMultiplier: speedMultiplier,
            remainingLoops: repeatModes[verseID] ?? .off
        )

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = makeUtterance(
            text: text,
            translation: translation,
            speedMultiplier: speedMultiplier
        )
        synthesizer.speak(utterance)
    }

    func advanceRepeatMode(for verseID: UUID) {
        let nextMode = (repeatModes[verseID] ?? .off).next
        repeatModes[verseID] = nextMode

        if activePlayback?.verseID == verseID {
            activePlayback?.remainingLoops = nextMode
        }
    }

    func repeatBadge(for verseID: UUID) -> String? {
        switch repeatModes[verseID] ?? .off {
        case .off:
            return nil
        case .once:
            return "+1"
        case .twice:
            return "+2"
        case .infinite:
            return "\u{221E}"
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard var playback = activePlayback else { return }

        switch playback.remainingLoops {
        case .off:
            activePlayback = nil
        case .once:
            playback.remainingLoops = .off
            activePlayback = playback
            synthesizer.speak(
                makeUtterance(
                    text: playback.text,
                    translation: playback.translation,
                    speedMultiplier: playback.speedMultiplier
                )
            )
        case .twice:
            playback.remainingLoops = .once
            activePlayback = playback
            synthesizer.speak(
                makeUtterance(
                    text: playback.text,
                    translation: playback.translation,
                    speedMultiplier: playback.speedMultiplier
                )
            )
        case .infinite:
            activePlayback = playback
            synthesizer.speak(
                makeUtterance(
                    text: playback.text,
                    translation: playback.translation,
                    speedMultiplier: playback.speedMultiplier
                )
            )
        }
    }

    private func makeUtterance(
        text: String,
        translation: Translation,
        speedMultiplier: Double
    ) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: translation.speechLanguageCode)
        let normalizedMultiplier = min(max(speedMultiplier, 0.1), 2.0)
        let scaledRate = AVSpeechUtteranceDefaultSpeechRate * Float(normalizedMultiplier)
        utterance.rate = min(max(scaledRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        return utterance
    }
}

private enum RepeatMode: Equatable {
    case off
    case once
    case twice
    case infinite

    var next: RepeatMode {
        switch self {
        case .off:
            return .once
        case .once:
            return .twice
        case .twice:
            return .infinite
        case .infinite:
            return .off
        }
    }
}

private struct ActivePlayback {
    let verseID: UUID
    let text: String
    let translation: Translation
    let speedMultiplier: Double
    var remainingLoops: RepeatMode
}
