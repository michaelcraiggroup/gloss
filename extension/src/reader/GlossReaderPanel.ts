import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class GlossReaderPanel {
	public static currentPanels: Map<string, GlossReaderPanel> = new Map();
	public static readonly viewType = 'glossReader';

	private readonly _panel: vscode.WebviewPanel;
	private readonly _uri: vscode.Uri;
	private readonly _extensionUri: vscode.Uri;
	private _disposables: vscode.Disposable[] = [];

	public static createOrShow(extensionUri: vscode.Uri, uri: vscode.Uri) {
		const column = vscode.window.activeTextEditor
			? vscode.window.activeTextEditor.viewColumn
			: undefined;

		const uriString = uri.toString();

		// If we already have a panel for this file, show it
		if (GlossReaderPanel.currentPanels.has(uriString)) {
			GlossReaderPanel.currentPanels.get(uriString)!._panel.reveal(column);
			return;
		}

		// Otherwise, create a new panel
		const fileName = path.basename(uri.fsPath, path.extname(uri.fsPath));
		const panel = vscode.window.createWebviewPanel(
			GlossReaderPanel.viewType,
			`📖 ${fileName}`,
			column || vscode.ViewColumn.One,
			{
				enableScripts: true,
				localResourceRoots: [
					vscode.Uri.joinPath(extensionUri, 'media'),
					vscode.Uri.joinPath(extensionUri, 'node_modules')
				],
				retainContextWhenHidden: true
			}
		);

		const glossPanel = new GlossReaderPanel(panel, extensionUri, uri);
		GlossReaderPanel.currentPanels.set(uriString, glossPanel);
	}

	public static revive(panel: vscode.WebviewPanel, extensionUri: vscode.Uri, uri: vscode.Uri) {
		const glossPanel = new GlossReaderPanel(panel, extensionUri, uri);
		GlossReaderPanel.currentPanels.set(uri.toString(), glossPanel);
	}

	private constructor(panel: vscode.WebviewPanel, extensionUri: vscode.Uri, uri: vscode.Uri) {
		this._panel = panel;
		this._extensionUri = extensionUri;
		this._uri = uri;

		// Set initial content
		this._update();

		// Watch for file changes
		const watcher = vscode.workspace.createFileSystemWatcher(uri.fsPath);
		watcher.onDidChange(() => this._update());
		this._disposables.push(watcher);

		// Handle panel disposal
		this._panel.onDidDispose(() => this.dispose(), null, this._disposables);

		// Handle messages from webview
		this._panel.webview.onDidReceiveMessage(
			message => {
				switch (message.command) {
					case 'edit':
						this._openInEditor();
						break;
					case 'copyCode':
						vscode.env.clipboard.writeText(message.code);
						vscode.window.showInformationMessage('Code copied to clipboard');
						break;
				}
			},
			null,
			this._disposables
		);
	}

	private async _openInEditor() {
		// Remove from reading mode tracking
		GlossReaderPanel.currentPanels.delete(this._uri.toString());
		this._panel.dispose();
		
		// Open in editor
		const doc = await vscode.workspace.openTextDocument(this._uri);
		await vscode.window.showTextDocument(doc);
	}

	public dispose() {
		GlossReaderPanel.currentPanels.delete(this._uri.toString());

		this._panel.dispose();

		while (this._disposables.length) {
			const disposable = this._disposables.pop();
			if (disposable) {
				disposable.dispose();
			}
		}
	}

	private async _update() {
		const webview = this._panel.webview;
		
		try {
			const content = await fs.promises.readFile(this._uri.fsPath, 'utf8');
			const html = await this._getHtmlForWebview(webview, content);
			this._panel.webview.html = html;
		} catch (error) {
			this._panel.webview.html = this._getErrorHtml(webview, `Failed to read file: ${error}`);
		}
	}

	private async _getHtmlForWebview(webview: vscode.Webview, markdown: string): Promise<string> {
		// Dynamic import for ESM module
		const { marked } = await import('marked');
		
		// Simple code block rendering without external highlighter
		// The webview will handle highlighting via CSS classes
		const htmlContent = await marked.parse(markdown);
		const fileName = path.basename(this._uri.fsPath);
		const config = vscode.workspace.getConfiguration('gloss');
		const isDark = vscode.window.activeColorTheme.kind === vscode.ColorThemeKind.Dark;

		return `<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${webview.cspSource} 'unsafe-inline'; script-src 'unsafe-inline';">
	<title>${fileName}</title>
	<style>
		${this._getStyles(isDark)}
	</style>
</head>
<body>
	<div class="gloss-toolbar">
		<span class="gloss-title">📖 ${fileName}</span>
		<div class="gloss-actions">
			<button onclick="editFile()" title="Edit this file (Cmd+Shift+E)">
				✏️ Edit
			</button>
		</div>
	</div>
	<article class="gloss-content">
		${htmlContent}
	</article>
	<script>
		const vscode = acquireVsCodeApi();
		
		function editFile() {
			vscode.postMessage({ command: 'edit' });
		}

		// Add copy buttons to code blocks
		document.querySelectorAll('pre code').forEach((block) => {
			const pre = block.parentElement;
			const button = document.createElement('button');
			button.className = 'copy-button';
			button.textContent = '📋 Copy';
			button.onclick = () => {
				vscode.postMessage({ command: 'copyCode', code: block.textContent });
				button.textContent = '✓ Copied';
				setTimeout(() => button.textContent = '📋 Copy', 2000);
			};
			pre.style.position = 'relative';
			pre.appendChild(button);
		});

		// Keyboard shortcut for edit
		document.addEventListener('keydown', (e) => {
			if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === 'e') {
				e.preventDefault();
				editFile();
			}
		});
	</script>
</body>
</html>`;
	}

	private _getStyles(isDark: boolean): string {
		const bg = isDark ? '#1e1e1e' : '#ffffff';
		const fg = isDark ? '#d4d4d4' : '#333333';
		const accent = '#0d9488'; // Teal - Gloss brand color
		const accentLight = isDark ? '#14b8a6' : '#0d9488';
		const codeBg = isDark ? '#2d2d2d' : '#f5f5f5';
		const borderColor = isDark ? '#404040' : '#e0e0e0';
		const toolbarBg = isDark ? '#252526' : '#f8f8f8';

		return `
			* {
				box-sizing: border-box;
			}

			body {
				font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
				line-height: 1.7;
				color: ${fg};
				background: ${bg};
				margin: 0;
				padding: 0;
			}

			.gloss-toolbar {
				position: sticky;
				top: 0;
				background: ${toolbarBg};
				border-bottom: 1px solid ${borderColor};
				padding: 8px 24px;
				display: flex;
				justify-content: space-between;
				align-items: center;
				z-index: 100;
			}

			.gloss-title {
				font-weight: 600;
				font-size: 14px;
				opacity: 0.8;
			}

			.gloss-actions button {
				background: transparent;
				border: 1px solid ${borderColor};
				border-radius: 4px;
				padding: 4px 12px;
				cursor: pointer;
				font-size: 13px;
				color: ${fg};
				transition: all 0.15s ease;
			}

			.gloss-actions button:hover {
				background: ${accent};
				border-color: ${accent};
				color: white;
			}

			.gloss-content {
				max-width: 800px;
				margin: 0 auto;
				padding: 32px 24px 64px;
			}

			h1, h2, h3, h4, h5, h6 {
				margin-top: 1.5em;
				margin-bottom: 0.5em;
				font-weight: 600;
				line-height: 1.3;
			}

			h1 {
				font-size: 2em;
				border-bottom: 2px solid ${accentLight};
				padding-bottom: 0.3em;
			}

			h2 {
				font-size: 1.5em;
				border-bottom: 1px solid ${borderColor};
				padding-bottom: 0.2em;
			}

			h3 { font-size: 1.25em; }
			h4 { font-size: 1.1em; }

			p {
				margin: 1em 0;
			}

			a {
				color: ${accentLight};
				text-decoration: none;
			}

			a:hover {
				text-decoration: underline;
			}

			code {
				font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, monospace;
				font-size: 0.9em;
				background: ${codeBg};
				padding: 2px 6px;
				border-radius: 4px;
			}

			pre {
				background: ${codeBg};
				padding: 16px;
				border-radius: 8px;
				overflow-x: auto;
				border: 1px solid ${borderColor};
				position: relative;
			}

			pre code {
				background: none;
				padding: 0;
				font-size: 0.85em;
				line-height: 1.5;
			}

			.copy-button {
				position: absolute;
				top: 8px;
				right: 8px;
				background: ${isDark ? '#3d3d3d' : '#e8e8e8'};
				border: none;
				border-radius: 4px;
				padding: 4px 8px;
				font-size: 12px;
				cursor: pointer;
				opacity: 0;
				transition: opacity 0.15s ease;
			}

			pre:hover .copy-button {
				opacity: 1;
			}

			.copy-button:hover {
				background: ${accent};
				color: white;
			}

			blockquote {
				margin: 1em 0;
				padding: 0.5em 1em;
				border-left: 4px solid ${accentLight};
				background: ${codeBg};
				border-radius: 0 8px 8px 0;
			}

			blockquote p {
				margin: 0.5em 0;
			}

			ul, ol {
				padding-left: 1.5em;
			}

			li {
				margin: 0.3em 0;
			}

			table {
				width: 100%;
				border-collapse: collapse;
				margin: 1em 0;
			}

			th, td {
				border: 1px solid ${borderColor};
				padding: 8px 12px;
				text-align: left;
			}

			th {
				background: ${codeBg};
				font-weight: 600;
			}

			tr:nth-child(even) {
				background: ${isDark ? '#252525' : '#fafafa'};
			}

			hr {
				border: none;
				border-top: 1px solid ${borderColor};
				margin: 2em 0;
			}

			img {
				max-width: 100%;
				height: auto;
				border-radius: 8px;
			}

			/* Syntax highlighting - GitHub-like */
			.hljs-comment, .hljs-quote { color: ${isDark ? '#6a737d' : '#6a737d'}; }
			.hljs-keyword, .hljs-selector-tag { color: ${isDark ? '#ff7b72' : '#d73a49'}; }
			.hljs-string, .hljs-addition { color: ${isDark ? '#a5d6ff' : '#032f62'}; }
			.hljs-number { color: ${isDark ? '#79c0ff' : '#005cc5'}; }
			.hljs-function, .hljs-title { color: ${isDark ? '#d2a8ff' : '#6f42c1'}; }
			.hljs-variable, .hljs-attr { color: ${isDark ? '#79c0ff' : '#005cc5'}; }
			.hljs-built_in { color: ${isDark ? '#ffa657' : '#e36209'}; }
		`;
	}

	private _getErrorHtml(webview: vscode.Webview, error: string): string {
		return `<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<title>Error</title>
	<style>
		body {
			font-family: system-ui, sans-serif;
			display: flex;
			justify-content: center;
			align-items: center;
			height: 100vh;
			margin: 0;
			background: #1e1e1e;
			color: #d4d4d4;
		}
		.error {
			text-align: center;
			padding: 20px;
		}
		.error h1 { color: #f87171; }
	</style>
</head>
<body>
	<div class="error">
		<h1>⚠️ Error</h1>
		<p>${error}</p>
	</div>
</body>
</html>`;
	}
}
