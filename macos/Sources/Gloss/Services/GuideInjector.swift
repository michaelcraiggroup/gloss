import Foundation

/// Injects the Rabble Guide SDK into rendered HTML for walkthrough support.
struct GuideInjector {
    /// Cached bundle JS to avoid re-reading from disk on every render.
    private static let bundleJS: String? = {
        let bundleURL: URL?
        #if XCODE_BUILD
        bundleURL = Bundle.main.url(forResource: "rabble-guide", withExtension: "js")
        #else
        bundleURL = Bundle.module.url(forResource: "rabble-guide", withExtension: "js")
        #endif

        guard let bundleURL,
              let js = try? String(contentsOf: bundleURL, encoding: .utf8) else {
            return nil
        }
        return js
    }()

    /// Inject the Rabble Guide IIFE bundle and initialization code into HTML.
    /// The SDK is inert until `window.glossGuide.startStep()` is called.
    static func injectGuideSDK(into html: String) -> String {
        guard let bundleJS else { return html }
        return injectScript(bundleJS, into: html)
    }

    private static func postGuide(_ obj: String) -> String {
        "window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.glossGuide&&window.webkit.messageHandlers.glossGuide.postMessage(\(obj))"
    }

    private static func injectScript(_ bundleJS: String, into html: String) -> String {
        let post = postGuide
        // The IIFE bundle defines var RabbleGuideModule = (function(exports){...})({}).
        // We assign window.RabbleGuide after the IIFE so the global is available.
        let initScript = """
        <script>\(bundleJS)
        ;window.RabbleGuide=RabbleGuideModule.RabbleGuide;</script>
        <script>
        (function() {
            var post = function(obj) { \(post("JSON.stringify(obj)")); };
            try {
                if (!window.RabbleGuide) {
                    post({ type: 'error', message: 'RabbleGuide class not found on window' });
                    return;
                }
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

                sdk.on('complete', function() { post({ type: 'complete' }); });
                sdk.on('stop', function() { post({ type: 'skip' }); });

                post({ type: 'ready' });
            } catch(e) {
                post({ type: 'error', message: String(e) });
            }
        })();
        </script>
        """

        return html.replacingOccurrences(of: "</body>", with: "\(initScript)</body>")
    }
}
