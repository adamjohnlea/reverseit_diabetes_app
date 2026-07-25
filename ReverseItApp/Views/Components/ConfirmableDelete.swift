import SwiftUI

extension View {
    /// Presents a destructive confirmation dialog before deleting `item`.
    ///
    /// Stash the candidate in an optional `@State` from the delete gesture and
    /// bind it here; `onConfirm` runs only after the user confirms, and the
    /// binding is cleared when the dialog is dismissed either way.
    func confirmDelete<Item>(
        _ title: LocalizedStringKey,
        item: Binding<Item?>,
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        item.wrappedValue = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: item.wrappedValue
        ) { value in
            Button("Delete", role: .destructive) {
                onConfirm(value)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
