import Foundation

/// Classifies markdown documents by folder context or filename patterns.
/// Ported from extension/src/merrily/treeProvider.ts:175-195.
enum DocumentType: String, CaseIterable, Sendable {
    case pitch
    case retrospective
    case strategy
    case principle
    case audit
    case flashcard
    case template
    case decision
    case research
    case readme
    case changelog
    case plan
    case folder
    case generic

    var icon: String {
        switch self {
        case .pitch: "💡"
        case .retrospective: "📊"
        case .strategy: "🎯"
        case .principle: "⚖️"
        case .audit: "🔍"
        case .flashcard: "🃏"
        case .template: "📋"
        case .decision: "⚡"
        case .research: "🔬"
        case .readme: "📖"
        case .changelog: "📝"
        case .plan: "🗺️"
        case .folder: "📂"
        case .generic: "📄"
        }
    }

    var displayName: String {
        switch self {
        case .pitch: "Pitch"
        case .retrospective: "Retrospective"
        case .strategy: "Strategy"
        case .principle: "Principle"
        case .audit: "Audit"
        case .flashcard: "Flashcard"
        case .template: "Template"
        case .decision: "Decision"
        case .research: "Research"
        case .readme: "README"
        case .changelog: "Changelog"
        case .plan: "Plan"
        case .folder: "Folder"
        case .generic: "Document"
        }
    }

    /// Detect document type from filename and parent folder name.
    static func detect(filename: String, folderName: String = "") -> DocumentType {
        let lowerName = filename.lowercased()
        let lowerFolder = folderName.lowercased()

        if lowerFolder == "pitches" || lowerName.contains("pitch") { return .pitch }
        if lowerFolder == "retrospectives" || lowerName.contains("retro") { return .retrospective }
        if lowerFolder == "strategies" || lowerName.contains("strategy") { return .strategy }
        if lowerFolder == "principles" || lowerName.contains("principle") { return .principle }
        if lowerFolder == "audits" || lowerName.contains("audit") { return .audit }
        if lowerFolder == "flashcards" || lowerName.contains("flashcard") { return .flashcard }
        if lowerFolder == "templates" || lowerName.contains("template") { return .template }
        if lowerFolder == "decisions" || lowerName.contains("decision") || lowerName.contains("adr") { return .decision }
        if lowerFolder == "research" || lowerName.contains("brief") { return .research }
        if lowerName.contains("readme") { return .readme }
        if lowerName.contains("changelog") { return .changelog }
        if lowerName.contains("plan") { return .plan }

        return .generic
    }
}
