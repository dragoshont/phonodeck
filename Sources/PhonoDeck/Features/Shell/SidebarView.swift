import SwiftUI

struct SidebarView: View {
    @Binding var selection: LibrarySection?

    var body: some View {
        List(selection: $selection) {
            Section("PhonoDeck") {
                ForEach([LibrarySection.listenNow, .library, .search]) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            Section("Library") {
                ForEach([LibrarySection.albums, .artists, .playlists, .downloads]) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            Section("System") {
                ForEach([LibrarySection.devices, .settings]) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
    }
}
