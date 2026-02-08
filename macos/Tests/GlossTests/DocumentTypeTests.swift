import Testing
@testable import Gloss

@Suite("DocumentType")
struct DocumentTypeTests {

    // MARK: - Folder-based detection

    @Test("Detects pitch from folder name")
    func pitchFolder() {
        #expect(DocumentType.detect(filename: "cool-idea.md", folderName: "pitches") == .pitch)
    }

    @Test("Detects retrospective from folder name")
    func retroFolder() {
        #expect(DocumentType.detect(filename: "q1-review.md", folderName: "retrospectives") == .retrospective)
    }

    @Test("Detects strategy from folder name")
    func strategyFolder() {
        #expect(DocumentType.detect(filename: "growth.md", folderName: "strategies") == .strategy)
    }

    @Test("Detects principle from folder name")
    func principleFolder() {
        #expect(DocumentType.detect(filename: "privacy.md", folderName: "principles") == .principle)
    }

    @Test("Detects decision from folder name")
    func decisionFolder() {
        #expect(DocumentType.detect(filename: "0001-use-swift.md", folderName: "decisions") == .decision)
    }

    // MARK: - Filename-based detection

    @Test("Detects pitch from filename")
    func pitchFilename() {
        #expect(DocumentType.detect(filename: "PITCH_dark_mode.md") == .pitch)
    }

    @Test("Detects retro from filename")
    func retroFilename() {
        #expect(DocumentType.detect(filename: "retrospective-q2.md") == .retrospective)
    }

    @Test("Detects ADR as decision")
    func adrFilename() {
        #expect(DocumentType.detect(filename: "ADR-0003.md") == .decision)
    }

    @Test("Detects readme")
    func readmeFilename() {
        #expect(DocumentType.detect(filename: "README.md") == .readme)
    }

    @Test("Detects changelog")
    func changelogFilename() {
        #expect(DocumentType.detect(filename: "CHANGELOG.md") == .changelog)
    }

    @Test("Detects plan")
    func planFilename() {
        #expect(DocumentType.detect(filename: "PROJECT_PLAN.md") == .plan)
    }

    @Test("Returns generic for unknown files")
    func genericFallback() {
        #expect(DocumentType.detect(filename: "notes.md") == .generic)
    }

    // MARK: - Properties

    @Test("All cases have non-empty icons")
    func icons() {
        for type in DocumentType.allCases {
            #expect(!type.icon.isEmpty)
        }
    }

    @Test("All cases have non-empty display names")
    func displayNames() {
        for type in DocumentType.allCases {
            #expect(!type.displayName.isEmpty)
        }
    }
}
