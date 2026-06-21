import SwiftUI

struct PhonoDeckWelcomeSheet: View {
    let continueAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            HStack {
                Spacer()
                Button("Continue") {
                    continueAction()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "music.note.house")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to PhonoDeck")
                    .font(.title2.weight(.semibold))
                Text("Bringing all music into one place.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Start with the Library, then add the music services you want PhonoDeck to bring together.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}