import SwiftUI

struct SidebarView: View {
    @Binding var selection: LibrarySection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                brandHeader
                SidebarSection(title: "PhonoDeck", sections: [.library], selection: $selection)
                SidebarSection(title: "Library", sections: [.playlists, .albums, .artists], selection: $selection)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
        }
        .background(.bar, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
        }
        .padding(.leading, 10)
        .padding(.vertical, 10)
    }

    private var brandHeader: some View {
        Label {
            Text("PhonoDeck")
                .font(.headline.weight(.semibold))
        } icon: {
            Image(systemName: "music.note.house")
                .foregroundStyle(Color.accentColor)
        }
        .font(.title3.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .accessibilityLabel("PhonoDeck")
    }
}

private struct SidebarSection: View {
    let title: String
    let sections: [LibrarySection]
    @Binding var selection: LibrarySection?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            .padding(.horizontal, 12)

            ForEach(sections) { section in
                SidebarButton(section: section, isSelected: selection == section) {
                    selection = section
                }
            }
        }
    }
}

private struct SidebarButton: View {
    let section: LibrarySection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(section.title, systemImage: section.symbolName)
                .font(.title3.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .accessibilityLabel(section.title)
    }
}
