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
        // CSS is injected immediately (non-blocking), but the 70KB SDK bundle and
        // initialization are deferred with setTimeout(0) so they run after the first
        // paint — the SDK is inert until startStep() anyway.
        let initScript = """
        <style>
        .rg-popover, .rg-popover .rg-popover__content,
        .rg-popover .rg-popover__content p,
        .rg-popover .rg-popover__content li,
        .rg-popover .rg-popover__content h1,
        .rg-popover .rg-popover__content h2,
        .rg-popover .rg-popover__content h3 {
            color: #1a1a2e !important;
        }
        .rg-popover .rg-popover__content code,
        .rg-popover .rg-popover__content pre {
            color: #1a1a2e !important;
            background: rgba(0, 0, 0, 0.06) !important;
        }
        .rg-popover .rg-popover__content pre code {
            background: transparent !important;
        }
        .rg-popover .rg-popover__content a {
            color: var(--rg-primary, #4876d6) !important;
        }
        .rg-btn--primary { color: #ffffff !important; }
        </style>
        <script>
        setTimeout(function() {
            \(bundleJS)
            ;window.RabbleGuide=RabbleGuideModule.RabbleGuide;

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

                var session = Date.now();
                var stepCounter = 0;
                var suppressStop = false;

                window.glossGuide = {
                    startStep: function(stepJSON, current, total) {
                        stepCounter++;
                        var guideId = 'gloss-' + session + '-' + stepCounter + '-' + stepJSON.id;
                        suppressStop = true;
                        sdk.stop();
                        suppressStop = false;
                        sdk.reset(guideId);

                        var doStart = function() {
                            sdk.start({ id: guideId, name: 'step', version: 1, steps: [stepJSON] })
                                .then(function() {
                                    var el = document.querySelector('.rg-popover__progress');
                                    if (el && current && total) {
                                        el.textContent = current + ' of ' + total;
                                    }
                                })
                                .catch(function(err) {
                                    post({ type: 'error', message: 'start failed: ' + String(err) });
                                });
                        };
                        if (stepJSON.target) {
                            var target = document.querySelector(stepJSON.target);
                            if (target) {
                                target.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                setTimeout(doStart, 250);
                            } else { doStart(); }
                        } else { doStart(); }
                    },
                    stop: function() {
                        suppressStop = true;
                        sdk.stop();
                        suppressStop = false;
                    },
                };

                sdk.on('complete', function() {
                    suppressStop = true;
                    post({ type: 'complete' });
                    setTimeout(function() { suppressStop = false; }, 50);
                });
                sdk.on('stop', function() {
                    if (suppressStop) return;
                    post({ type: 'skip' });
                });

                post({ type: 'ready' });
            } catch(e) {
                post({ type: 'error', message: String(e) });
            }
        }, 0);
        </script>
        """

        return html.replacingOccurrences(of: "</body>", with: "\(initScript)</body>")
    }
}
