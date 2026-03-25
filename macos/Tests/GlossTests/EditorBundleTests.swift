import Foundation
import Testing
@testable import Gloss

@Suite("Editor Bundle")
struct EditorBundleTests {

    // MARK: - Resource Loading

    @Test("CodeMirror bundle resource exists")
    func bundleResourceExists() {
        let url = Bundle.module.url(forResource: "codemirror-bundle", withExtension: "js")
        #expect(url != nil, "codemirror-bundle.js must be included as a SPM resource")
    }

    @Test("CodeMirror bundle is non-empty")
    func bundleResourceNonEmpty() throws {
        let url = try #require(Bundle.module.url(forResource: "codemirror-bundle", withExtension: "js"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.count > 10_000, "Bundle should be substantial (~500KB)")
    }

    @Test("CodeMirror bundle exposes CM global")
    func bundleExposesCMGlobal() throws {
        let url = try #require(Bundle.module.url(forResource: "codemirror-bundle", withExtension: "js"))
        let content = try String(contentsOf: url, encoding: .utf8)
        // IIFE with --global-name=CM assigns to var CM or globalThis.CM
        #expect(content.contains("CM"), "Bundle must define the CM global namespace")
    }

    @Test("Editor HTML template resource exists")
    func editorTemplateExists() {
        let url = Bundle.module.url(forResource: "editor", withExtension: "html")
        #expect(url != nil, "editor.html must be included as a SPM resource")
    }

    @Test("Editor HTML template contains bundle placeholder")
    func editorTemplateHasPlaceholder() throws {
        let url = try #require(Bundle.module.url(forResource: "editor", withExtension: "html"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("/* CODEMIRROR_BUNDLE */"), "Template must have placeholder for bundle injection")
    }

    @Test("Editor HTML template does NOT use CDN imports")
    func editorTemplateNoCDN() throws {
        let url = try #require(Bundle.module.url(forResource: "editor", withExtension: "html"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("esm.sh"), "Template must not load from CDN — bundle locally")
        #expect(!content.contains("type=\"module\""), "Template must not use ES modules — use IIFE bundle")
    }

    @Test("Editor HTML template destructures CM globals")
    func editorTemplateDestructuresCM() throws {
        let url = try #require(Bundle.module.url(forResource: "editor", withExtension: "html"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("} = CM;"), "Template must destructure from CM global")
        #expect(content.contains("EditorView"), "Template must reference EditorView")
        #expect(content.contains("EditorState"), "Template must reference EditorState")
    }

    @Test("Editor HTML template has font size placeholder")
    func editorTemplateFontSizePlaceholder() throws {
        let url = try #require(Bundle.module.url(forResource: "editor", withExtension: "html"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("/* FONT_SIZE_OVERRIDE */"), "Template must have font size placeholder")
    }

    @Test("Editor HTML template sends ready message")
    func editorTemplateSendsReady() throws {
        let url = try #require(Bundle.module.url(forResource: "editor", withExtension: "html"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("postMessage({ type: 'ready' })"), "Template must signal ready to Swift")
    }

    @Test("Editor HTML template exposes glossEditor API")
    func editorTemplateExposesAPI() throws {
        let url = try #require(Bundle.module.url(forResource: "editor", withExtension: "html"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("window.glossEditor"), "Template must expose glossEditor API")
        #expect(content.contains("setContent"), "API must include setContent")
        #expect(content.contains("getContent"), "API must include getContent")
        #expect(content.contains("markClean"), "API must include markClean")
    }

    // MARK: - Bundle Injection

    @Test("Bundle injection replaces placeholder in template")
    func bundleInjectionWorks() throws {
        let templateURL = try #require(Bundle.module.url(forResource: "editor", withExtension: "html"))
        let bundleURL = try #require(Bundle.module.url(forResource: "codemirror-bundle", withExtension: "js"))

        let template = try String(contentsOf: templateURL, encoding: .utf8)
        let bundle = try String(contentsOf: bundleURL, encoding: .utf8)

        let injected = template.replacingOccurrences(of: "/* CODEMIRROR_BUNDLE */", with: bundle)

        #expect(!injected.contains("/* CODEMIRROR_BUNDLE */"), "Placeholder must be fully replaced")
        #expect(injected.contains("EditorView"), "Injected HTML must contain CM6 code")
        #expect(injected.count > template.count + 100_000, "Injected HTML should be much larger")
    }

    @Test("Theme injection works")
    func themeInjection() throws {
        let url = try #require(Bundle.module.url(forResource: "editor", withExtension: "html"))
        let template = try String(contentsOf: url, encoding: .utf8)

        let dark = template.replacingOccurrences(
            of: "<html lang=\"en\">",
            with: "<html lang=\"en\" class=\"dark\">"
        )
        #expect(dark.contains("class=\"dark\""))

        let light = template.replacingOccurrences(
            of: "<html lang=\"en\">",
            with: "<html lang=\"en\" class=\"light\">"
        )
        #expect(light.contains("class=\"light\""))
    }
}
