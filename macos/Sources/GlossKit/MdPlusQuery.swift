import Foundation

/// Sort key for a `type: query` md+ block.
public enum MdPlusQuerySort: String, Sendable, Hashable, Codable {
    case title
    case modified
}

/// Sort direction for a `type: query` md+ block.
public enum MdPlusQueryOrder: String, Sendable, Hashable, Codable {
    case asc
    case desc
}

/// A single frontmatter-property equality filter (`where: { key: value }`).
public struct MdPlusPropertyFilter: Sendable, Hashable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// A parsed `type: query` md+ block — a declarative query over the link index.
/// All filters are optional and AND-combined. Resolved at render time by an
/// app-supplied closure (GlossKit itself has no database access).
public struct MdPlusQuery: Sendable, Hashable {
    public let id: String
    public let title: String?
    /// Note must have ALL of these tags.
    public let tags: [String]
    /// Frontmatter `key == value` filters (AND).
    public let properties: [MdPlusPropertyFilter]
    /// Notes whose links resolve to this target name.
    public let linksTo: String?
    /// Full-text (FTS5) match.
    public let search: String?
    public let sort: MdPlusQuerySort
    public let order: MdPlusQueryOrder
    public let limit: Int
    public let rawYAML: String

    public init(
        id: String,
        title: String? = nil,
        tags: [String] = [],
        properties: [MdPlusPropertyFilter] = [],
        linksTo: String? = nil,
        search: String? = nil,
        sort: MdPlusQuerySort = .title,
        order: MdPlusQueryOrder = .asc,
        limit: Int = 50,
        rawYAML: String = ""
    ) {
        self.id = id
        self.title = title
        self.tags = tags
        self.properties = properties
        self.linksTo = linksTo
        self.search = search
        self.sort = sort
        self.order = order
        self.limit = limit
        self.rawYAML = rawYAML
    }

    /// True when the query carries no filters at all (lists the whole vault, limited).
    public var hasNoFilters: Bool {
        tags.isEmpty && properties.isEmpty && linksTo == nil && (search?.isEmpty ?? true)
    }
}

/// A single result row from running an `MdPlusQuery`. `url` is a `file://`
/// URL string so query-result links navigate through the same WebView
/// interception as resolved wiki-links.
public struct MdPlusQueryRow: Sendable, Hashable {
    public let title: String
    public let url: String
    public let subtitle: String?

    public init(title: String, url: String, subtitle: String? = nil) {
        self.title = title
        self.url = url
        self.subtitle = subtitle
    }
}
