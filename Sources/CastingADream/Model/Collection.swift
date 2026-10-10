import Foundation

/// Links into collection.stevan.co.rs. Games there have no pages of their own, but the site keeps
/// its search in the URL: `q` is matched against title, platform, edition and genre, and
/// `platforms` filters by platform, so title + platform narrows the list down to the one game.
/// When the folder name doesn't match the collection's title (a translation, another romanization),
/// a collection.txt in the game's folder holds the search to use instead.
enum Collection {
    static let home = URL(string: "https://collection.stevan.co.rs/")!

    static func url(for game: Game) -> URL {
        var components = URLComponents(url: home, resolvingAgainstBaseURL: false)!
        // Encode everything but unreserved characters: the site reads the query with URLSearchParams,
        // which would take a literal "&" as a new parameter and "+" as a space.
        components.percentEncodedQuery = [
            ("q", game.collectionQuery ?? game.title),
            ("platforms", game.system.collectionPlatform),
        ]
        .map { "\($0)=\(encode($1))" }
        .joined(separator: "&")
        return components.url!
    }

    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

extension GameSystem {
    /// Platform name as the collection spells it.
    var collectionPlatform: String {
        switch self {
        case .dreamcast: "Dreamcast"
        case .psp: "PSP"
        case .wii: "Wii"
        case .gamecube: "GCN"
        case .famicom: "Famicom"
        }
    }
}
