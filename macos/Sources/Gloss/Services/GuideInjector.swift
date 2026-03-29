import Foundation

/// Injects the Rabble Guide SDK into rendered HTML for walkthrough support.
struct GuideInjector {
    /// Inject the Rabble Guide IIFE bundle and initialization code into HTML.
    /// The SDK is inert until `window.glossGuide.startStep()` is called.
    static func injectGuideSDK(into html: String) -> String {
        guard let bundleURL = Bundle.main.url(forResource: "rabble-guide", withExtension: "js"),
              let bundleJS = try? String(contentsOf: bundleURL, encoding: .utf8) else {
            #if SPM_BUILD
            // Try SPM bundle
            if let bundleURL = Bundle.module.url(forResource: "rabble-guide", withExtension: "js"),
               let bundleJS = try? String(contentsOf: bundleURL, encoding: .utf8) {
                return injectScript(bundleJS, into: html)
            }
            #endif
            return html // Graceful degradation
        }
        return injectScript(bundleJS, into: html)
    }

    private static func injectScript(_ bundleJS: String, into html: String) -> String {
        let initScript = """
        <script>\(bundleJS)</script>
        <script>
        (function() {
            var sdk = window.RabbleGuide.init({
                theme: {
                    primary: getComputedStyle(document.documentElement)
                        .getPropertyValue('--accent').trim() || '#4876d6',
                    fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
                    zIndex: 10000,
                },
            });

            window.glossGuide = {
                startStep: function(stepJSON) {
                    sdk.start({ id: 'gloss-step', name: 'step', version: 1, steps: [stepJSON] });
                },
                stop: function() { sdk.stop(); },
            };

            sdk.on('complete', function() {
                window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.glossGuide &&
                    window.webkit.messageHandlers.glossGuide.postMessage(
                        JSON.stringify({ type: 'complete' })
                    );
            });
            sdk.on('skip', function() {
                window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.glossGuide &&
                    window.webkit.messageHandlers.glossGuide.postMessage(
                        JSON.stringify({ type: 'skip' })
                    );
            });

            window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.glossGuide &&
                window.webkit.messageHandlers.glossGuide.postMessage(
                    JSON.stringify({ type: 'ready' })
                );
        })();
        </script>
        """

        return html.replacingOccurrences(of: "</body>", with: "\(initScript)</body>")
    }
}
