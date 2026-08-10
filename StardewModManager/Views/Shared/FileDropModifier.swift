import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Accepts file-URL drops, resolving the dropped providers into local URLs and
    /// delivering them (non-empty only) on the main queue. Consolidates the single
    /// race-safe drop implementation that InstalledModsView and ModpackListView shared.
    ///
    /// - Parameters:
    ///   - isTargeted: Optional binding set while a drag hovers the drop region.
    ///   - perform: Called on the main queue with the collected URLs when at least one
    ///     provider resolved to a URL.
    func onModDrop(isTargeted: Binding<Bool>? = nil, perform: @escaping ([URL]) -> Void) -> some View {
        onDrop(of: [.fileURL], isTargeted: isTargeted) { providers in
            var urls: [URL] = []
            let urlsLock = NSLock()
            let group = DispatchGroup()

            for provider in providers {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                    if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        // Completion handlers fire concurrently on arbitrary queues; serialize the append.
                        urlsLock.lock()
                        urls.append(url)
                        urlsLock.unlock()
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                if !urls.isEmpty {
                    perform(urls)
                }
            }

            return true
        }
    }
}
