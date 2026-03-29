import Foundation
import Testing
@testable import Gloss

@Suite("Guide Injector")
struct GuideInjectorTests {

    @Test("Rabble Guide JS bundle resource exists")
    func bundleResourceExists() {
        let url = Bundle.module.url(forResource: "rabble-guide", withExtension: "js")
        #expect(url != nil, "rabble-guide.js must be included as a SPM resource")
    }

    @Test("Rabble Guide JS bundle is non-empty")
    func bundleResourceNonEmpty() throws {
        let url = try #require(Bundle.module.url(forResource: "rabble-guide", withExtension: "js"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.count > 50_000, "Bundle should be substantial (~70KB)")
    }

    @Test("Rabble Guide JS bundle exposes RabbleGuide class")
    func bundleExposesRabbleGuide() throws {
        let url = try #require(Bundle.module.url(forResource: "rabble-guide", withExtension: "js"))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("RabbleGuide"), "Bundle must define RabbleGuide")
        #expect(content.contains("static init"), "Bundle must contain static init method")
        #expect(content.contains("RabbleGuideModule"), "Bundle must define RabbleGuideModule IIFE global")
    }

    @Test("SDK injection into HTML with </body>")
    func injectionIntoHTMLWithBody() {
        let html = GuideInjector.injectGuideSDK(into: "<html><body><p>Test</p></body></html>")
        #expect(html.contains("window.RabbleGuide"), "Injected HTML must contain SDK bundle")
        #expect(html.contains("window.glossGuide"), "Injected HTML must define glossGuide API")
        #expect(html.contains("</body></html>"), "Must preserve </body></html> structure")
    }

    @Test("SDK injection preserves HTML without </body>")
    func injectionWithoutBody() {
        let html = "<html><p>No body tag</p></html>"
        let result = GuideInjector.injectGuideSDK(into: html)
        #expect(result == html, "HTML without </body> should be unchanged")
    }

    @Test("Injected script posts ready message")
    func injectedScriptPostsReady() {
        let html = GuideInjector.injectGuideSDK(into: "<body></body>")
        #expect(html.contains("type: 'ready'"), "Must post ready message to Swift")
    }

    @Test("Injected script handles complete and stop events")
    func injectedScriptHandlesEvents() {
        let html = GuideInjector.injectGuideSDK(into: "<body></body>")
        #expect(html.contains("type: 'complete'"), "Must forward complete events")
        #expect(html.contains("type: 'skip'"), "Must forward skip/stop events")
    }

    @Test("WebStep JSON serialization includes all fields")
    func webStepJSON() {
        let step = WebStep(id: "test-step", type: "content", target: nil, content: "Hello", placement: "center")
        let json = step.jsonObject
        #expect(json["id"] as? String == "test-step")
        #expect(json["type"] as? String == "content")
        #expect(json["content"] as? String == "Hello")
        #expect(json["placement"] as? String == "center")
        #expect(json["target"] == nil)
    }

    @Test("WebStep JSON serialization includes target when present")
    func webStepJSONWithTarget() {
        let step = WebStep(id: "spot", type: "spotlight", target: "h1", content: "Look here", placement: "bottom")
        let json = step.jsonObject
        #expect(json["target"] as? String == "h1")
    }

    @Test("WalkthroughGuide definitions are valid")
    func guideDefinitionsValid() {
        let gs = WalkthroughGuide.gettingStarted
        #expect(!gs.id.isEmpty)
        #expect(!gs.steps.isEmpty)
        #expect(gs.steps.count >= 3, "Getting Started should have multiple steps")

        let wn = WalkthroughGuide.whatsNewTags
        #expect(!wn.id.isEmpty)
        #expect(!wn.steps.isEmpty)
    }
}
