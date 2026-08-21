import SwiftUI

struct PrimaryEditorialButton: View {
    let title: String
    let enabled: Bool
    var inverted = false
    let action: () -> Void

    var body: some View {
        AppButton(
            title: title,
            role: inverted ? .secondary : .primary,
            enabled: enabled,
            action: action
        )
    }
}
