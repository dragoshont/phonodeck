import SwiftUI

struct SidebarView: View {
    @Binding var selection: LibrarySection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                brandHeader
                SidebarSection(title: "PhonoDeck", sections: [.library, .search], selection: $selection)
                SidebarSection(title: "Library", sections: [.playlists, .albums, .artists, .queue, .downloads], selection: $selection)
                SidebarSection(title: "System", sections: [.devices, .settings], selection: $selection)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .background(.bar)
    }

    private var brandHeader: some View {
        Label {
            Text("PhonoDeck")
                .font(.headline.weight(.semibold))
        } icon: {
            Image(systemName: "music.note.house")
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .accessibilityLabel("PhonoDeck")
    }
}

private struct SidebarSection: View {
    let title: String
    let sections: [LibrarySection]
    @Binding var selection: LibrarySection?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

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
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .accessibilityLabel(section.title)
    }
}
