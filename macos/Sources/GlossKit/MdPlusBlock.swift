import Foundation

/// Field type for `template` md+ blocks. v1 supports a minimal set of input types.
public enum TemplateFieldKind: String, Sendable, Hashable, Codable {
    case text
    case number
    case checkbox
    case date
    case select
}

/// A single field in an `md+` template block.
public struct TemplateField: Sendable, Hashable {
    public let name: String
    public let kind: TemplateFieldKind
    public let label: String
    public let defaultValue: String?
    public let options: [String]
    public let multiline: Bool

    public init(
        name: String,
        kind: TemplateFieldKind,
        label: String,
        defaultValue: String? = nil,
        options: [String] = [],
        multiline: Bool = false
    ) {
        self.name = name
        self.kind = kind
        self.label = label
        self.defaultValue = defaultValue
        self.options = options
        self.multiline = multiline
    }
}

/// A parsed `md+` block extracted from a markdown source. v1 supports `type: template`.
public struct MdPlusBlock: Sendable, Hashable {
    public let id: String
    public let name: String?
    public let type: String
    public let fields: [TemplateField]
    public let rawYAML: String

    public init(
        id: String,
        name: String?,
        type: String,
        fields: [TemplateField],
        rawYAML: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.fields = fields
        self.rawYAML = rawYAML
    }
}
