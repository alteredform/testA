import SwiftUI

struct FiltersView: View {
    let items: [ArchiveItem]
    @Binding var selectedServices: Set<String>
    @Binding var selectedCategories: Set<String>
    @Binding var selectedOther: Set<String>

    @Environment(\.dismiss) private var dismiss

    private var allServices: [String] {
        Array(Set(items.flatMap { $0.services })).sorted()
    }
    private var allCategories: [String] {
        Array(Set(items.flatMap { $0.tags })).sorted()
    }
    private var allOther: [String] {
        var out = Set<String>()
        for item in items {
            if item.isMissing { out.insert("Missing") }
            if item.isNew { out.insert("New") }
        }
        return out.sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                if !allServices.isEmpty {
                    Section("Services") {
                        ForEach(allServices, id: \.self) { value in
                            Toggle(value, isOn: binding(for: value, in: $selectedServices))
                        }
                    }
                }
                if !allCategories.isEmpty {
                    Section("Categories") {
                        ForEach(allCategories, id: \.self) { value in
                            Toggle(value, isOn: binding(for: value, in: $selectedCategories))
                        }
                    }
                }
                if !allOther.isEmpty {
                    Section("Other") {
                        ForEach(allOther, id: \.self) { value in
                            Toggle(value, isOn: binding(for: value, in: $selectedOther))
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        selectedServices.removeAll()
                        selectedCategories.removeAll()
                        selectedOther.removeAll()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func binding(for value: String, in set: Binding<Set<String>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(value) },
            set: { isOn in
                if isOn { set.wrappedValue.insert(value) }
                else { set.wrappedValue.remove(value) }
            }
        )
    }
}