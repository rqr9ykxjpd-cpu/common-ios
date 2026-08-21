import SwiftUI

struct DiscoveryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DiscoveryFilters
    let apply: (DiscoveryFilters) -> Void

    init(filters: DiscoveryFilters, apply: @escaping (DiscoveryFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.apply = apply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Discovery.ageRange) {
                    Stepper(L10n.Discovery.minAge(draft.minimumAge), value: $draft.minimumAge, in: 18...draft.maximumAge)
                    Stepper(L10n.Discovery.maxAge(draft.maximumAge), value: $draft.maximumAge, in: draft.minimumAge...99)
                }
                Section(L10n.Discovery.yearSection) {
                    ForEach(AcademicYear.all, id: \.self) { year in
                        toggleRow(AcademicYear.display(year), selected: draft.academicYears.contains(year)) {
                            toggle(year, in: &draft.academicYears)
                        }
                    }
                }
                Section(L10n.Discovery.departmentSection) {
                    ForEach(DepartmentCatalog.all, id: \.self) { department in
                        toggleRow(DepartmentCatalog.display(department), selected: draft.departments.contains(department)) {
                            toggle(department, in: &draft.departments)
                        }
                    }
                }
                Section(L10n.Discovery.priorities) {
                    Toggle(L10n.Discovery.commonInterest, isOn: $draft.requiresCommonInterest)
                    Toggle(L10n.Discovery.sameCampus, isOn: $draft.campusOnly)
                }
            }
            .navigationTitle(L10n.Discovery.filterTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Discovery.apply) { apply(draft); dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); if selected { Image(systemName: "checkmark").foregroundStyle(CampusTheme.violet) } }
        }.foregroundStyle(CampusTheme.ink)
    }

    private func toggle(_ value: String, in values: inout Set<String>) {
        if values.contains(value) { values.remove(value) } else { values.insert(value) }
    }
}
