import SwiftUI

/// "Çalışma grubu kur": yer, saat, kısa not, isteğe bağlı kontenjan.
struct StudyGroupComposer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var placeID: UUID?
    @State private var startsAt: Date = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
    @State private var note = ""
    @State private var limitsHeadcount = false
    @State private var capacity = 4
    @State private var isSending = false

    private var place: CampusPlace? { appState.places.first { $0.id == placeID } }
    private var canPublish: Bool { place != nil && !isSending && startsAt > Date().addingTimeInterval(-15 * 60) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.StudyGroup.composerHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section(L10n.StudyGroup.place) {
                    Picker(L10n.StudyGroup.place, selection: $placeID) {
                        ForEach(appState.places) { yer in
                            Text(yer.name).tag(Optional(yer.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section(L10n.StudyGroup.time) {
                    DatePicker(
                        L10n.StudyGroup.time,
                        selection: $startsAt,
                        in: Date()...(Calendar.current.date(byAdding: .day, value: 6, to: .now) ?? .now),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                }
                Section {
                    TextField(L10n.StudyGroup.notePlaceholder, text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .onChange(of: note) { _, value in
                            if value.count > 140 { note = String(value.prefix(140)) }
                        }
                    Toggle(L10n.StudyGroup.capacityToggle, isOn: $limitsHeadcount.animation())
                    if limitsHeadcount {
                        Stepper(L10n.StudyGroup.capacityValue(capacity), value: $capacity, in: 2...30)
                    }
                }
            }
            .navigationTitle(L10n.StudyGroup.composerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }.disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard let place else { return }
                        isSending = true
                        Task {
                            let oldu = await appState.createStudyGroup(
                                place: place, startsAt: startsAt, note: note,
                                capacity: limitsHeadcount ? capacity : nil
                            )
                            isSending = false
                            if oldu { dismiss() }
                        }
                    } label: {
                        if isSending { ProgressView() } else { Text(L10n.StudyGroup.publish).fontWeight(.semibold) }
                    }
                    .disabled(!canPublish)
                }
            }
            .interactiveDismissDisabled(isSending)
            .task {
                if appState.places.isEmpty { await appState.loadPlaces() }
                if placeID == nil {
                    // Kim nerede'de görünür olduğu yer varsa o, yoksa ilk yer.
                    placeID = appState.currentVisiblePlace?.id ?? appState.places.first?.id
                }
            }
        }
    }
}
