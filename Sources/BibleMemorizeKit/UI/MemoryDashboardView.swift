import SwiftUI
import AVFoundation
import MediaPlayer
import Speech
#if canImport(UIKit)
import UIKit
#endif

public struct MemoryDashboardView: View {
    @State private var viewModel: DashboardViewModel
    @StateObject private var speaker = VerseSpeaker()
    @StateObject private var recitationRecognizer = VerseRecitationRecognizer()
    @State private var isShowingAddVerse = false
    @State private var editingCard: MemorizationCard?
    @State private var editingVerseText = ""
    @State private var editingVerseTranslation: Translation = .nkjv
    @State private var editingAssignmentType: VerseAssignmentType = .dueNow
    @State private var highlightedMicPromptID: UUID?
    @State private var isMicPulseExpanded = false
    @State private var isDueDropTargeted = false
    @State private var isUpcomingDropTargeted = false
    @State private var dueReorderTargetID: UUID?

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
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.blue)

                            Text("Bible Memorize")
                                .font(.headline.weight(.semibold))
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
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
                .sheet(item: $editingCard) { card in
                    EditVerseView(
                        reference: card.verse.reference,
                        translation: $editingVerseTranslation,
                        verseText: $editingVerseText,
                        assignmentType: $editingAssignmentType
                    ) {
                        saveEditedVerse(cardID: card.id)
                    }
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
        .onAppear {
            isMicPulseExpanded = true
            setIdleTimerDisabled(viewModel.store.keepScreenAwake)
        }
        .onChange(of: viewModel.store.keepScreenAwake) { _, keepAwake in
            setIdleTimerDisabled(keepAwake)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            HStack(spacing: 12) {
                StatCard(title: "Due", value: "\(viewModel.dueCount)")
                StatCard(title: "Pass", value: "\(viewModel.passCount)") {
                    if viewModel.passCount > 0 {
                        viewModel.store.resetAllPassedPrompts()
                        recitationRecognizer.resetCurrentReview()
                        if let prompt = viewModel.store.todaysSession?.currentPrompt {
                            updateMicHighlight(for: prompt.cardID, isPassed: false)
                        }
                    }
                }
                StatCard(title: "Progress", value: "\(Int(viewModel.reviewCompletion * 100))%")
            }

            HStack(spacing: 12) {
                if viewModel.store.todaysSession != nil {
                    sessionNavButton(
                        systemName: "chevron.left",
                        accessibilityLabel: "Previous Verse",
                        isEnabled: viewModel.store.todaysSession?.canMoveToPreviousPrompt ?? false
                    ) {
                        viewModel.store.moveToPreviousSessionPrompt()
                    }
                }

                Button {
                    viewModel.store.toggleSession()
                } label: {
                    Image(systemName: viewModel.store.todaysSession == nil ? "play.circle.fill" : "eye.slash.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(viewModel.store.todaysSession == nil ? "Start Review Session" : "Hide Review Session")

                if viewModel.store.todaysSession != nil {
                    sessionNavButton(
                        systemName: "chevron.right",
                        accessibilityLabel: "Next Verse",
                        isEnabled: viewModel.store.todaysSession?.canMoveToNextPrompt ?? false
                    ) {
                        viewModel.store.moveToNextSessionPrompt()
                    }
                }
            }

            if let prompt = viewModel.store.todaysSession?.currentPrompt {
                let isPromptPassed = recitationRecognizer.isComplete(for: prompt.cardID) || viewModel.store.isPromptPassed(prompt.cardID)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(prompt.reference)
                            .font(.headline)

                        Spacer()

                        controls(for: prompt, isPromptPassed: isPromptPassed)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(recitationRecognizer.displayText(for: prompt))
                                .foregroundStyle(isPromptPassed ? .green : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if recitationRecognizer.isRecording(for: prompt.cardID) || !recitationRecognizer.transcript(for: prompt.cardID).isEmpty {
                                if recitationRecognizer.isRecording(for: prompt.cardID) {
                                    VoiceInputIndicator(level: recitationRecognizer.inputLevel(for: prompt.cardID))
                                }

                                Text(recitationRecognizer.transcript(for: prompt.cardID))
                                    .font(.subheadline)
                                    .foregroundStyle(isPromptPassed ? .green : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxHeight: 180)

                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onAppear {
                    updateMicHighlight(for: prompt.cardID, isPassed: isPromptPassed)
                    recitationRecognizer.prepare(
                        verseID: prompt.cardID,
                        targetText: prompt.promptText,
                        translation: viewModel.store.selectedTranslation,
                        maskedWords: prompt.maskedWords
                    )
                }
                .onChange(of: prompt.id) { _, _ in
                    updateMicHighlight(for: prompt.cardID, isPassed: isPromptPassed)
                    recitationRecognizer.prepare(
                        verseID: prompt.cardID,
                        targetText: prompt.promptText,
                        translation: viewModel.store.selectedTranslation,
                        maskedWords: prompt.maskedWords
                    )
                }
                .onChange(of: recitationRecognizer.isComplete(for: prompt.cardID)) { _, isComplete in
                    if isComplete {
                        viewModel.store.recordPassedReviewIfNeeded(
                            cardID: prompt.cardID,
                            elapsedSeconds: recitationRecognizer.elapsedSeconds(for: prompt.cardID)
                        )
                        highlightedMicPromptID = nil
                    } else if !viewModel.store.isPromptPassed(prompt.cardID) {
                        viewModel.store.resetPromptPassed(cardID: prompt.cardID)
                        updateMicHighlight(for: prompt.cardID, isPassed: false)
                    }
                }
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
                    speedMultiplier: viewModel.store.speechRateMultiplier,
                    isPassed: viewModel.store.isPromptPassed(card.id),
                    onEdit: {
                        beginEditing(card)
                    },
                    onDelete: {
                        viewModel.store.deleteVerse(cardID: card.id)
                    }
                )
                .overlay {
                    if dueReorderTargetID == card.id {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
                .draggable(card.id.uuidString)
                .dropDestination(for: String.self) { items, _ in
                    handleDueReorderDrop(items: items, targetCardID: card.id)
                } isTargeted: { isTargeted in
                    dueReorderTargetID = isTargeted ? card.id : (dueReorderTargetID == card.id ? nil : dueReorderTargetID)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.store.deleteVerse(cardID: card.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            dueDropTargetRow
        }
    }

    private var dueDropTargetRow: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(isDueDropTargeted ? Color.green : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
            .overlay {
                HStack(spacing: 10) {
                    Image(systemName: isDueDropTargeted ? "plus.circle.fill" : "arrow.up.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isDueDropTargeted ? .green : .secondary)

                    Text(isDueDropTargeted ? "Drop to move into Due Now" : "Hold and drag an upcoming verse here")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isDueDropTargeted ? .white : .secondary)
                }
            }
            .frame(height: 64)
            .background(isDueDropTargeted ? Color.green.opacity(0.18) : Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .dropDestination(for: String.self) { items, _ in
                handleDueDrop(items: items)
            } isTargeted: { isTargeted in
                isDueDropTargeted = isTargeted
            }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.headline)

            dropTargetRow

            ForEach(viewModel.store.upcomingCards) { card in
                VerseRow(
                    card: card,
                    translation: viewModel.store.selectedTranslation,
                    speaker: speaker,
                    speedMultiplier: viewModel.store.speechRateMultiplier,
                    isPassed: false,
                    onEdit: {
                        beginEditing(card)
                    },
                    onDelete: {
                        viewModel.store.deleteVerse(cardID: card.id)
                    }
                )
                .draggable(card.id.uuidString)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.store.deleteVerse(cardID: card.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var dropTargetRow: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(isUpcomingDropTargeted ? Color.blue : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
            .overlay {
                HStack(spacing: 10) {
                    Image(systemName: isUpcomingDropTargeted ? "plus.circle.fill" : "arrow.down.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isUpcomingDropTargeted ? .blue : .secondary)

                    Text(isUpcomingDropTargeted ? "Drop to move into Upcoming" : "Hold and drag a due verse here")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isUpcomingDropTargeted ? .white : .secondary)
                }
            }
            .frame(height: 64)
            .background(isUpcomingDropTargeted ? Color.blue.opacity(0.18) : Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .dropDestination(for: String.self) { items, _ in
                handleUpcomingDrop(items: items)
            } isTargeted: { isTargeted in
                isUpcomingDropTargeted = isTargeted
            }
    }

    @ViewBuilder
    private func controls(for prompt: SessionPrompt, isPromptPassed: Bool) -> some View {
        let shouldHighlightMic = highlightedMicPromptID == prompt.cardID && !isPromptPassed

        HStack(spacing: 14) {
            if isPromptPassed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.green)
                    .clipShape(Circle())
            }

            Button {
                speaker.togglePlayback(
                    verseID: prompt.cardID,
                    text: prompt.promptText,
                    translation: viewModel.store.selectedTranslation,
                    speedMultiplier: viewModel.store.speechRateMultiplier
                )
            } label: {
                Image(systemName: speaker.iconName(for: prompt.cardID))
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Speak verse")

            Button {
                speaker.advanceRepeatMode(for: prompt.cardID)
            } label: {
                Image(systemName: "repeat")
                    .font(.headline)
                    .overlay(alignment: .topTrailing) {
                        if let label = speaker.repeatBadge(for: prompt.cardID) {
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

            Button {
                highlightedMicPromptID = nil
                recitationRecognizer.toggleRecording(
                    verseID: prompt.cardID,
                    targetText: prompt.promptText,
                    maskedWords: prompt.maskedWords,
                    translation: viewModel.store.selectedTranslation
                )
            } label: {
                Image(systemName: recitationRecognizer.isRecording(for: prompt.cardID) ? "waveform.circle.fill" : "mic.fill")
                    .font(.headline)
                    .foregroundStyle(recitationRecognizer.isRecording(for: prompt.cardID) ? .red : (recitationRecognizer.isComplete(for: prompt.cardID) ? .green : .primary))
                    .scaleEffect(shouldHighlightMic && isMicPulseExpanded ? 1.15 : 1.0)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(shouldHighlightMic ? 0.18 : 0))
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.red.opacity(shouldHighlightMic ? 0.8 : 0), lineWidth: 1.5)
                            .scaleEffect(shouldHighlightMic && isMicPulseExpanded ? 1.35 : 1.0)
                    }
                    .animation(
                        shouldHighlightMic
                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.2),
                        value: shouldHighlightMic
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Record recitation")
        }
    }

    private func handleUpcomingDrop(items: [String]) -> Bool {
        guard let item = items.first,
              let cardID = UUID(uuidString: item.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        viewModel.store.moveCardToUpcoming(cardID: cardID)
        return true
    }

    private func handleDueDrop(items: [String]) -> Bool {
        guard let item = items.first,
              let cardID = UUID(uuidString: item.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        viewModel.store.moveCardToDueNow(cardID: cardID)
        return true
    }

    private func handleDueReorderDrop(items: [String], targetCardID: UUID) -> Bool {
        guard let item = items.first,
              let draggedCardID = UUID(uuidString: item.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        let dueIDs = Set(viewModel.store.dueCards.map(\.id))
        guard dueIDs.contains(draggedCardID), dueIDs.contains(targetCardID) else {
            return false
        }

        viewModel.store.reorderDueCard(cardID: draggedCardID, before: targetCardID)
        dueReorderTargetID = nil
        return true
    }

    private func beginEditing(_ card: MemorizationCard) {
        editingVerseText = card.verse.text(for: card.verse.defaultTranslation)
        editingVerseTranslation = card.verse.defaultTranslation
        editingAssignmentType = viewModel.store.assignmentType(for: card.id)
        editingCard = card
    }

    private func saveEditedVerse(cardID: UUID) {
        let trimmedText = editingVerseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTranslation = viewModel.store.cards.first(where: { $0.id == cardID })?.verse.defaultTranslation ?? editingVerseTranslation

        viewModel.store.updateVerseText(
            cardID: cardID,
            translation: editingVerseTranslation,
            text: trimmedText
        )
        viewModel.store.updateVerseBibleVersion(
            cardID: cardID,
            from: previousTranslation,
            to: editingVerseTranslation,
            text: trimmedText
        )
        viewModel.store.updateAssignmentType(cardID: cardID, assignmentType: editingAssignmentType)
        editingCard = nil
    }

    private func updateMicHighlight(for promptID: UUID, isPassed: Bool) {
        highlightedMicPromptID = isPassed ? nil : promptID
        if !isMicPulseExpanded {
            isMicPulseExpanded = true
        }
    }

    private func sessionNavButton(
        systemName: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 26, weight: .bold))
                .frame(width: 72)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

private func setIdleTimerDisabled(_ isDisabled: Bool) {
    #if canImport(UIKit)
    UIApplication.shared.isIdleTimerDisabled = isDisabled
    #endif
}

private struct VoiceInputIndicator: View {
    let level: Double

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<14, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index < activeBars ? activeColor(for: index) : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 14)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.12), value: activeBars)
    }

    private var activeBars: Int {
        min(14, Int((level * 14).rounded(.up)))
    }

    private func activeColor(for index: Int) -> Color {
        index < 2 ? .red : .secondary.opacity(0.85)
    }
}

private struct AddVerseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: BibleMemorizeStore
    @StateObject private var dictationRecorder = VerseDictationRecorder()

    @State private var selectedTranslation: Translation = .nkjv
    @State private var selectedBook: BibleBook = .john
    @State private var selectedChapter = 1
    @State private var selectedVerseStart = 1
    @State private var selectedVerseEndEnabled = false
    @State private var selectedVerseEnd = 1
    @State private var verseText = ""
    @State private var tagsText = ""
    @State private var difficulty: VerseDifficulty = .medium
    @State private var assignmentType: VerseAssignmentType = .dueNow

    private var isValid: Bool {
        !verseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var availableChapters: [Int] {
        Array(1...selectedBook.chapterCount)
    }

    private var availableVerses: [Int] {
        let maxVerse = selectedBook.verseCount(in: selectedChapter) ?? 1
        return Array(1...maxVerse)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reference") {
                    Picker("Bible Version", selection: $selectedTranslation) {
                        ForEach(Translation.allCases) { translation in
                            Text(translation.rawValue).tag(translation)
                        }
                    }

                    Menu {
                        Picker("Book", selection: $selectedBook) {
                            ForEach(BibleBook.allCases) { book in
                                Text(book.displayName(for: selectedTranslation)).tag(book)
                            }
                        }
                    } label: {
                        HStack {
                            Text("Book")
                            Spacer()
                            Text(selectedBook.displayName(for: selectedTranslation))
                                .foregroundStyle(.tint)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

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
                    Picker("Type", selection: $assignmentType) {
                        ForEach(VerseAssignmentType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Tags (comma separated)", text: $tagsText)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(VerseDifficulty.allCases) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Verse Text")
                            Spacer()
                            if dictationRecorder.isRecording {
                                VoiceInputIndicator(level: dictationRecorder.inputLevel)
                                    .frame(width: 140)
                            }
                            Button {
                                dictationRecorder.toggleRecording(translation: selectedTranslation)
                            } label: {
                                Image(systemName: dictationRecorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(dictationRecorder.isRecording ? .red : .blue)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(dictationRecorder.isRecording ? "Stop voice input" : "Start voice input")
                        }

                        TextField("Verse Text", text: $verseText, axis: .vertical)
                            .lineLimit(5...10)

                        if let statusMessage = dictationRecorder.statusMessage {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Verse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVerse()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            selectedTranslation = store.selectedTranslation
            normalizeReferenceSelection()
        }
        .onDisappear {
            dictationRecorder.stop()
        }
        .onChange(of: selectedBook) { _, _ in
            normalizeReferenceSelection()
        }
        .onChange(of: selectedChapter) { _, _ in
            normalizeReferenceSelection()
        }
        .onChange(of: selectedVerseStart) { _, newValue in
            if selectedVerseEnd < newValue {
                selectedVerseEnd = newValue
            }
        }
        .onChange(of: selectedVerseEndEnabled) { _, isEnabled in
            if isEnabled {
                selectedVerseEnd = max(selectedVerseEnd, selectedVerseStart)
                normalizeReferenceSelection()
            }
        }
        .onChange(of: dictationRecorder.transcript) { _, transcript in
            verseText = transcript
        }
    }

    private func normalizeReferenceSelection() {
        let clampedChapter = min(max(selectedChapter, 1), selectedBook.chapterCount)
        if clampedChapter != selectedChapter {
            selectedChapter = clampedChapter
        }

        let maxVerse = selectedBook.verseCount(in: selectedChapter) ?? 1
        let clampedVerseStart = min(max(selectedVerseStart, 1), maxVerse)
        if clampedVerseStart != selectedVerseStart {
            selectedVerseStart = clampedVerseStart
        }

        let clampedVerseEnd = min(max(selectedVerseEnd, selectedVerseStart), maxVerse)
        if clampedVerseEnd != selectedVerseEnd {
            selectedVerseEnd = clampedVerseEnd
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
            difficulty: difficulty,
            assignmentType: assignmentType
        )

        dismiss()
    }
}

private struct SettingsView: View {
    @Bindable var store: BibleMemorizeStore
    @State private var isShowingResetProgressConfirmation = false

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

                    HStack(spacing: 12) {
                        Button {
                            adjustSpeechRate(by: -0.1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.speechRateMultiplier <= 0.1)

                        Slider(
                            value: $store.speechRateMultiplier,
                            in: 0.1...2.0,
                            step: 0.1
                        )

                        Button {
                            adjustSpeechRate(by: 0.1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.speechRateMultiplier >= 2.0)
                    }

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

            Section("Display") {
                Toggle("Keep Screen Awake", isOn: $store.keepScreenAwake)

                Text("When enabled, the screen stays on while this app is open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("AI (OpenAI) Mode") {
                Toggle("Enable AI Mode", isOn: Binding(
                    get: { store.isOpenAIEnabled },
                    set: { store.setOpenAIEnabled($0) }
                ))

                SecureField("OpenAI API Key", text: $store.openAIAPIKey)
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

            Section("Progress") {
                Button(role: .destructive) {
                    isShowingResetProgressConfirmation = true
                } label: {
                    Text("Reset Progress")
                }

                Text("This clears review history, mastery, streaks, and passed state, but keeps your verses.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Reset all progress data?",
            isPresented: $isShowingResetProgressConfirmation,
            titleVisibility: .visible
        ) {
            Button("OK", role: .destructive) {
                store.resetProgressData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All review history, mastery, streaks, and pass progress will be removed.")
        }
    }

    private func adjustSpeechRate(by delta: Double) {
        let nextValue = (store.speechRateMultiplier + delta).rounded(toPlaces: 1)
        store.speechRateMultiplier = min(max(nextValue, 0.1), 2.0)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let action: (() -> Void)?

    init(title: String, value: String, action: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.action = action
    }

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
        .overlay(alignment: .topTrailing) {
            if let action {
                Button(action: action) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
    }
}

private struct EditVerseView: View {
    @Environment(\.dismiss) private var dismiss

    let reference: BibleReference
    @Binding var translation: Translation
    @Binding var verseText: String
    @Binding var assignmentType: VerseAssignmentType
    let onSave: () -> Void

    private var isValid: Bool {
        !verseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reference") {
                    LabeledContent("Verse") {
                        Text(reference.formatted(for: translation))
                    }

                    Picker("Bible Version", selection: $translation) {
                        ForEach(Translation.allCases) { version in
                            Text(version.rawValue).tag(version)
                        }
                    }
                }

                Section("Verse Text") {
                    Picker("Type", selection: $assignmentType) {
                        ForEach(VerseAssignmentType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextEditor(text: $verseText)
                        .frame(minHeight: 220)
                }
            }
            .navigationTitle("Edit Verse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

private struct VerseRow: View {
    let card: MemorizationCard
    let translation: Translation
    @ObservedObject var speaker: VerseSpeaker
    let speedMultiplier: Double
    let isPassed: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isShowingDeleteConfirmation = false

    private var successfulPassCount: Int {
        card.reviewHistory.filter { $0.grade.rawValue >= RecallGrade.correct.rawValue }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(card.verse.reference.formatted(for: translation))
                    .font(.headline)

                Spacer()

                HStack(spacing: 14) {
                    if isPassed || successfulPassCount > 0 {
                        Text("\(successfulPassCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(minWidth: 24, minHeight: 24)
                            .padding(.horizontal, successfulPassCount >= 10 ? 6 : 0)
                            .background(.green)
                            .clipShape(Capsule())
                    }

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit verse")

                    Button {
                        speaker.togglePlayback(
                            verseID: card.id,
                            text: card.verse.text(for: translation),
                            translation: translation,
                            speedMultiplier: speedMultiplier
                        )
                    } label: {
                        Image(systemName: speaker.iconName(for: card.id))
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

                    Button {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete verse")
                }
            }
            ScrollView {
                Text(card.verse.text(for: translation))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 110)
            Text("Translation: \(translation.rawValue)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .confirmationDialog(
            "Delete this verse?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected verse.")
        }
    }
}

@MainActor
private final class VerseSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private var repeatModes: [UUID: RepeatMode] = [:]
    @Published private(set) var activeVerseID: UUID?
    @Published private(set) var isPaused = false

    private let synthesizer = AVSpeechSynthesizer()
    #if os(iOS)
    private let audioSession = AVAudioSession.sharedInstance()
    #endif
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    private var activePlayback: ActivePlayback?

    override init() {
        super.init()
        synthesizer.delegate = self
        configureRemoteCommands()
    }

    func togglePlayback(
        verseID: UUID,
        text: String,
        translation: Translation,
        speedMultiplier: Double
    ) {
        if activeVerseID == verseID {
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
                isPaused = false
                updateNowPlayingInfo()
                return
            }

            if synthesizer.isSpeaking {
                synthesizer.pauseSpeaking(at: .word)
                isPaused = true
                updateNowPlayingInfo()
                return
            }
        }

        configureAudioSession()

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

        activeVerseID = verseID
        isPaused = false
        updateNowPlayingInfo()

        let utterance = makeUtterance(
            text: text,
            translation: translation,
            speedMultiplier: speedMultiplier
        )
        synthesizer.speak(utterance)
    }

    func iconName(for verseID: UUID) -> String {
        guard activeVerseID == verseID else {
            return "speaker.wave.2.fill"
        }

        return isPaused ? "play.fill" : "pause.fill"
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #if canImport(UIKit)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            #endif
        } catch {
            do {
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
            } catch {
                print("Failed to configure audio session for verse playback: \(error)")
            }
        }
        #endif
    }

    private func configureRemoteCommands() {
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = true

        remoteCommandCenter.playCommand.addTarget { [weak self] _ in
            self?.resumeFromRemoteControl() ?? .commandFailed
        }

        remoteCommandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pauseFromRemoteControl() ?? .commandFailed
        }

        remoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }

            if self.synthesizer.isPaused {
                return self.resumeFromRemoteControl()
            }

            if self.synthesizer.isSpeaking {
                return self.pauseFromRemoteControl()
            }

            return .commandFailed
        }
    }

    private func pauseFromRemoteControl() -> MPRemoteCommandHandlerStatus {
        guard synthesizer.isSpeaking else {
            return .commandFailed
        }

        guard synthesizer.pauseSpeaking(at: .word) else {
            return .commandFailed
        }

        isPaused = true
        updateNowPlayingInfo()
        return .success
    }

    private func resumeFromRemoteControl() -> MPRemoteCommandHandlerStatus {
        guard synthesizer.isPaused else {
            return .commandFailed
        }

        guard synthesizer.continueSpeaking() else {
            return .commandFailed
        }

        isPaused = false
        updateNowPlayingInfo()
        return .success
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
            activeVerseID = nil
            isPaused = false
            clearNowPlayingInfo()
        case .once:
            playback.remainingLoops = .off
            activePlayback = playback
            updateNowPlayingInfo()
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
            updateNowPlayingInfo()
            synthesizer.speak(
                makeUtterance(
                    text: playback.text,
                    translation: playback.translation,
                    speedMultiplier: playback.speedMultiplier
                )
            )
        case .infinite:
            activePlayback = playback
            updateNowPlayingInfo()
            synthesizer.speak(
                makeUtterance(
                    text: playback.text,
                    translation: playback.translation,
                    speedMultiplier: playback.speedMultiplier
                )
            )
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        activePlayback = nil
        activeVerseID = nil
        isPaused = false
        clearNowPlayingInfo()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isPaused = true
        updateNowPlayingInfo()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isPaused = false
        updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        guard let playback = activePlayback else {
            clearNowPlayingInfo()
            return
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Bible Memorize",
            MPMediaItemPropertyArtist: playback.translation.rawValue,
            MPMediaItemPropertyAlbumTitle: "Verse Audio",
            MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: isPaused ? 0 : 1)
        ]
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #if canImport(UIKit)
        UIApplication.shared.endReceivingRemoteControlEvents()
        #endif
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

@MainActor
private final class VerseDictationRecorder: NSObject, ObservableObject {
    private enum DictationMessageKey {
        case unavailable
        case permissionRequired
    }

    private enum DictationError: Error {
        case permissionDenied
    }

    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var inputLevel: Double = 0

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentTranslation: Translation = .nkjv

    func toggleRecording(translation: Translation) {
        if isRecording {
            stop()
        } else {
            transcript = ""
            statusMessage = nil
            currentTranslation = translation
            Task {
                await start()
            }
        }
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        isRecording = false
        inputLevel = 0
    }

    private func start() async {
        do {
            try await requestPermissions()

            let locale = Locale(identifier: currentTranslation.speechLanguageCode)
            guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
                statusMessage = localizedMessage(.unavailable, translation: currentTranslation)
                return
            }

            speechRecognizer = recognizer
            recognitionTask?.cancel()
            recognitionTask = nil

            #if os(iOS)
            #if os(iOS)
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            #endif
            #endif

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
                let level = Self.audioLevel(from: buffer)
                Task { @MainActor in
                    self?.inputLevel = level
                }
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        self.transcript = self.sanitizeTranscript(result.bestTranscription.formattedString, translation: self.currentTranslation)
                        if result.isFinal {
                            self.stop()
                        }
                    } else if error != nil {
                        self.statusMessage = self.localizedMessage(.permissionRequired, translation: self.currentTranslation)
                        self.stop()
                    }
                }
            }
        } catch {
            statusMessage = localizedMessage(.permissionRequired, translation: currentTranslation)
            stop()
        }
    }

    private func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw DictationError.permissionDenied
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micGranted else {
            throw DictationError.permissionDenied
        }
    }

    private func sanitizeTranscript(_ text: String, translation: Translation) -> String {
        switch translation {
        case .korean:
            return text.filter { character in
                character.isWhitespace
                    || character.isNumber
                    || character.unicodeScalars.contains(where: { scalar in
                        (0x1100...0x11FF).contains(scalar.value)
                            || (0x3130...0x318F).contains(scalar.value)
                            || (0xAC00...0xD7AF).contains(scalar.value)
                    })
            }
        case .chinese:
            return text.filter { character in
                character.isWhitespace
                    || character.isNumber
                    || character.unicodeScalars.contains(where: { scalar in
                        (0x3400...0x4DBF).contains(scalar.value)
                            || (0x4E00...0x9FFF).contains(scalar.value)
                            || (0xF900...0xFAFF).contains(scalar.value)
                    })
            }
        case .japanese:
            return text.filter { character in
                character.isWhitespace
                    || character.isNumber
                    || character.unicodeScalars.contains(where: { scalar in
                        (0x3040...0x309F).contains(scalar.value)
                            || (0x30A0...0x30FF).contains(scalar.value)
                            || (0x4E00...0x9FFF).contains(scalar.value)
                    })
            }
        case .kjv, .nkjv, .spanish, .german:
            return text
        }
    }

    private func localizedMessage(_ key: DictationMessageKey, translation: Translation) -> String {
        switch (translation, key) {
        case (.korean, .unavailable):
            return "이 언어에서는 지금 음성 인식을 사용할 수 없습니다."
        case (.korean, .permissionRequired):
            return "음성 인식 권한이 필요합니다."
        case (.chinese, .unavailable):
            return "当前无法使用此语言的语音识别。"
        case (.chinese, .permissionRequired):
            return "需要语音识别权限。"
        case (.japanese, .unavailable):
            return "この言語では現在、音声認識を利用できません。"
        case (.japanese, .permissionRequired):
            return "音声認識の権限が必要です。"
        case (.spanish, .unavailable):
            return "El reconocimiento de voz no está disponible para este idioma ahora mismo."
        case (.spanish, .permissionRequired):
            return "Se requiere permiso para el reconocimiento de voz."
        case (.german, .unavailable):
            return "Die Spracherkennung ist für diese Sprache derzeit nicht verfügbar."
        case (.german, .permissionRequired):
            return "Für die Spracherkennung ist eine Berechtigung erforderlich."
        case (_, .unavailable):
            return "Speech recognition is unavailable for this language right now."
        case (_, .permissionRequired):
            return "Speech recognition permission is required."
        }
    }

    private static func audioLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channel = channelData[0]
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<frameLength {
            sum += channel[index] * channel[index]
        }

        let rms = sqrt(sum / Float(frameLength))
        return min(max(Double(rms) * 8, 0), 1)
    }
}

@MainActor
private final class VerseRecitationRecognizer: NSObject, ObservableObject {
    struct RecognitionState {
        var verseID: UUID
        var targetText: String
        var maskedWords: [String]
        var translation: Translation
        var startedAt: Date?
        var transcript: String = ""
        var isComplete = false
        var recognitionScore: Double = 0
        var inputLevel: Double = 0
    }

    @Published private var currentState: RecognitionState?
    @Published private var isRecording = false

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceGeneration = 0

    func prepare(verseID: UUID, targetText: String, translation: Translation, maskedWords: [String] = []) {
        guard currentState?.verseID != verseID || currentState?.targetText != targetText || currentState?.translation != translation else {
            return
        }
        stop()
        currentState = RecognitionState(
            verseID: verseID,
            targetText: targetText,
            maskedWords: maskedWords,
            translation: translation
        )
    }

    func toggleRecording(verseID: UUID, targetText: String, maskedWords: [String], translation: Translation) {
        prepare(verseID: verseID, targetText: targetText, translation: translation, maskedWords: maskedWords)
        if isRecording {
            stop()
        } else {
            Task {
                await start()
            }
        }
    }

    func transcript(for verseID: UUID) -> String {
        currentState?.verseID == verseID ? currentState?.transcript ?? "" : ""
    }

    func isRecording(for verseID: UUID) -> Bool {
        currentState?.verseID == verseID && isRecording
    }

    func isComplete(for verseID: UUID) -> Bool {
        currentState?.verseID == verseID && (currentState?.isComplete ?? false)
    }

    func inputLevel(for verseID: UUID) -> Double {
        currentState?.verseID == verseID ? currentState?.inputLevel ?? 0 : 0
    }

    func elapsedSeconds(for verseID: UUID) -> TimeInterval {
        guard currentState?.verseID == verseID,
              let startedAt = currentState?.startedAt else {
            return 0
        }
        return max(0, Date().timeIntervalSince(startedAt))
    }

    func displayText(for prompt: SessionPrompt) -> String {
        guard currentState?.verseID == prompt.cardID else {
            return prompt.maskedWords.joined(separator: " ")
        }

        let targetWords = prompt.promptText.split(separator: " ").map(String.init)
        let translation = currentState?.translation ?? .nkjv
        let transcriptText = transcript(for: prompt.cardID)
        let transcriptWords = normalize(transcriptText, translation: translation).split(separator: " ").map(String.init)
        let canonicalTranscript = canonicalComparisonText(transcriptText, translation: translation)

        let displayWords = prompt.maskedWords.enumerated().map { index, maskedWord in
            guard maskedWord == "____", index < targetWords.count else {
                return maskedWord
            }

            let normalizedTarget = normalize(targetWords[index], translation: translation)
            let canonicalTarget = canonicalComparisonText(targetWords[index], translation: translation)
            if transcriptWords.contains(normalizedTarget)
                || (!canonicalTarget.isEmpty && canonicalTranscript.contains(canonicalTarget))
                || isComplete(for: prompt.cardID) {
                return targetWords[index]
            }

            return maskedWord
        }

        return displayWords.joined(separator: " ")
    }

    func stop() {
        silenceGeneration += 1
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        isRecording = false
        currentState?.inputLevel = 0
    }

    func resetCurrentReview() {
        stop()
        guard let state = currentState else { return }
        currentState = RecognitionState(
            verseID: state.verseID,
            targetText: state.targetText,
            maskedWords: state.maskedWords,
            translation: state.translation
        )
    }

    private func start() async {
        guard let state = currentState else { return }
        do {
            try await requestPermissions()

            let locale = Locale(identifier: state.translation.speechLanguageCode)
            guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
                currentState?.transcript = localizedMessage(.unavailable, translation: state.translation)
                return
            }

            speechRecognizer = recognizer
            recognitionTask?.cancel()
            recognitionTask = nil

            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
                let level = Self.audioLevel(from: buffer)
                Task { @MainActor in
                    self?.currentState?.inputLevel = level
                }
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            currentState?.startedAt = .now
            scheduleSilenceTimeout()

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        let transcript = self.sanitizeTranscript(result.bestTranscription.formattedString, translation: state.translation)
                        self.currentState?.transcript = transcript
                        let score = self.recognitionScore(for: transcript)
                        let complete = (self.currentState?.isComplete ?? false)
                            || score >= 1
                            || self.allMaskedWordsRevealed(for: transcript)
                        self.currentState?.recognitionScore = score
                        self.currentState?.isComplete = complete
                        self.scheduleSilenceTimeout()

                        if complete || result.isFinal {
                            self.stop()
                        }
                    } else if error != nil {
                        self.stop()
                    }
                }
            }
        } catch {
            currentState?.transcript = localizedMessage(.permissionRequired, translation: state.translation)
            stop()
        }
    }

    private func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw RecognitionError.permissionDenied
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micGranted else {
            throw RecognitionError.permissionDenied
        }
    }

    private func completionReached(transcript: String) -> Bool {
        recognitionScore(for: transcript) >= 1
    }

    private func recognitionScore(for transcript: String) -> Double {
        guard let state = currentState else { return 0 }

        let normalizedTranscript = normalize(transcript, translation: state.translation)
        let normalizedTarget = normalize(state.targetText, translation: state.translation)
        let canonicalTranscript = canonicalComparisonText(transcript, translation: state.translation)
        let canonicalTarget = canonicalComparisonText(state.targetText, translation: state.translation)

        let spacedScore = similarityScore(lhs: normalizedTranscript, rhs: normalizedTarget)
        let canonicalScore = similarityScore(lhs: canonicalTranscript, rhs: canonicalTarget)
        return max(spacedScore, canonicalScore)
    }

    private func allMaskedWordsRevealed(for transcript: String) -> Bool {
        guard let state = currentState else { return false }

        let targetWords = state.targetText.split(separator: " ").map(String.init)
        let transcriptWords = normalize(transcript, translation: state.translation).split(separator: " ").map(String.init)
        let canonicalTranscript = canonicalComparisonText(transcript, translation: state.translation)

        for (index, maskedWord) in state.maskedWords.enumerated() {
            guard maskedWord == "____", index < targetWords.count else { continue }

            let normalizedTarget = normalize(targetWords[index], translation: state.translation)
            let canonicalTarget = canonicalComparisonText(targetWords[index], translation: state.translation)

            let isRevealed = transcriptWords.contains(normalizedTarget)
                || (!canonicalTarget.isEmpty && canonicalTranscript.contains(canonicalTarget))

            if !isRevealed {
                return false
            }
        }

        return true
    }

    private func normalize(_ text: String, translation: Translation) -> String {
        let sanitized = sanitizeTranscript(text, translation: translation)
        let filtered = String(
            sanitized
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .unicodeScalars
                .map { scalar in
                    CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar)
                        ? Character(scalar)
                        : " "
                }
        )

        return filtered
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
    }

    private func canonicalComparisonText(_ text: String, translation: Translation) -> String {
        normalize(text, translation: translation)
            .replacingOccurrences(of: " ", with: "")
    }

    private func similarityScore(lhs: String, rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs {
            return 1
        }

        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)
        let distance = levenshteinDistance(lhsCharacters, rhsCharacters)
        let longestCount = max(lhsCharacters.count, rhsCharacters.count)
        guard longestCount > 0 else { return 0 }
        return max(0, 1 - (Double(distance) / Double(longestCount)))
    }

    private func levenshteinDistance(_ lhs: [Character], _ rhs: [Character]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previous = Array(0...rhs.count)
        for (lhsIndex, lhsCharacter) in lhs.enumerated() {
            var current = [lhsIndex + 1]
            current.reserveCapacity(rhs.count + 1)

            for (rhsIndex, rhsCharacter) in rhs.enumerated() {
                let substitutionCost = lhsCharacter == rhsCharacter ? 0 : 1
                current.append(
                    min(
                        previous[rhsIndex + 1] + 1,
                        current[rhsIndex] + 1,
                        previous[rhsIndex] + substitutionCost
                    )
                )
            }

            previous = current
        }

        return previous[rhs.count]
    }

    private func sanitizeTranscript(_ text: String, translation: Translation) -> String {
        switch translation {
        case .korean:
            return text.filter { character in
                character.isWhitespace
                    || character.isNumber
                    || character.unicodeScalars.contains(where: { scalar in
                        (0x1100...0x11FF).contains(scalar.value)
                            || (0x3130...0x318F).contains(scalar.value)
                            || (0xAC00...0xD7AF).contains(scalar.value)
                    })
            }
        case .chinese:
            return text.filter { character in
                character.isWhitespace
                    || character.isNumber
                    || character.unicodeScalars.contains(where: { scalar in
                        (0x3400...0x4DBF).contains(scalar.value)
                            || (0x4E00...0x9FFF).contains(scalar.value)
                            || (0xF900...0xFAFF).contains(scalar.value)
                    })
            }
        case .japanese:
            return text.filter { character in
                character.isWhitespace
                    || character.isNumber
                    || character.unicodeScalars.contains(where: { scalar in
                        (0x3040...0x309F).contains(scalar.value)
                            || (0x30A0...0x30FF).contains(scalar.value)
                            || (0x4E00...0x9FFF).contains(scalar.value)
                    })
            }
        case .kjv, .nkjv, .spanish, .german:
            return text
        }
    }

    private func localizedMessage(_ key: RecognitionMessageKey, translation: Translation) -> String {
        switch (translation, key) {
        case (.korean, .unavailable):
            return "이 언어에서는 지금 음성 인식을 사용할 수 없습니다."
        case (.korean, .permissionRequired):
            return "음성 인식 권한이 필요합니다."
        case (.chinese, .unavailable):
            return "当前无法使用此语言的语音识别。"
        case (.chinese, .permissionRequired):
            return "需要语音识别权限。"
        case (.japanese, .unavailable):
            return "この言語では現在、音声認識を利用できません。"
        case (.japanese, .permissionRequired):
            return "音声認識の権限が必要です。"
        case (.spanish, .unavailable):
            return "El reconocimiento de voz no está disponible para este idioma ahora mismo."
        case (.spanish, .permissionRequired):
            return "Se requiere permiso para el reconocimiento de voz."
        case (.german, .unavailable):
            return "Die Spracherkennung ist für diese Sprache derzeit nicht verfügbar."
        case (.german, .permissionRequired):
            return "Für die Spracherkennung ist eine Berechtigung erforderlich."
        case (_, .unavailable):
            return "Speech recognition is unavailable for this language right now."
        case (_, .permissionRequired):
            return "Speech recognition permission is required."
        }
    }

    private func scheduleSilenceTimeout() {
        silenceGeneration += 1
        let generation = silenceGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard generation == self.silenceGeneration, self.isRecording else { return }
            self.stop()
        }
    }

    enum RecognitionError: Error {
        case permissionDenied
    }

    private enum RecognitionMessageKey {
        case unavailable
        case permissionRequired
    }

    private static func audioLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<frameLength {
            let sample = channelData[index]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        return min(max(Double(rms) * 10, 0), 1)
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
