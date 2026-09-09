import Foundation

struct VideoCandidate: Hashable {
    let elementID: String?
    let title: String
    let url: String?
    let poster: String?
    let kind: String
    let sourcePageURL: String?

    /// Stable key used for de-duplication and UI updates.
    var identityKey: String {
        [kind, elementID ?? "", url ?? "", title].joined(separator: "|")
    }
}
