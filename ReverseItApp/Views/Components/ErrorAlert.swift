import SwiftUI

extension View {
    /// Presents a standard error alert whenever `message` becomes non-nil.
    ///
    /// The single shared presentation path for surfacing recoverable errors;
    /// never swallow an error silently — route it here instead.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        message.wrappedValue = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
