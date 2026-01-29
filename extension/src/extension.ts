import * as vscode from 'vscode';
import { minimatch } from 'minimatch';
import { MerrilyTreeProvider } from './merrily/treeProvider';
import { MerrilyApiClient } from './merrily/apiClient';
import { GlossReaderPanel } from './reader/GlossReaderPanel';

let statusBarItem: vscode.StatusBarItem;
let merrilyTreeProvider: MerrilyTreeProvider;
let extensionUri: vscode.Uri;

export function activate(context: vscode.ExtensionContext) {
	console.log('Gloss extension activating...');

	// Store extension URI for webview resources
	extensionUri = context.extensionUri;

	// Initialize Merrily integration
	const apiClient = new MerrilyApiClient(context);
	merrilyTreeProvider = new MerrilyTreeProvider(apiClient);
	
	// Register Merrily tree view
	const treeView = vscode.window.createTreeView('glossMerrily', {
		treeDataProvider: merrilyTreeProvider,
		showCollapseAll: true
	});
	context.subscriptions.push(treeView);

	// Status bar indicator
	statusBarItem = vscode.window.createStatusBarItem(
		vscode.StatusBarAlignment.Right,
		100
	);
	statusBarItem.command = 'gloss.toggleEnabled';
	context.subscriptions.push(statusBarItem);
	updateStatusBar();

	// Register commands
	context.subscriptions.push(
		vscode.commands.registerCommand('gloss.editFile', editCurrentFile),
		vscode.commands.registerCommand('gloss.toggleEnabled', toggleEnabled),
		vscode.commands.registerCommand('gloss.openInReadingMode', openInReadingMode),
		vscode.commands.registerCommand('gloss.refreshMerrily', () => merrilyTreeProvider.refresh()),
		vscode.commands.registerCommand('gloss.configureMerrilyFolder', configureMerrilyFolder),
		vscode.commands.registerCommand('gloss.connectMerrilyApi', connectMerrilyApi),
		vscode.commands.registerCommand('gloss.disconnectMerrilyApi', disconnectMerrilyApi),
		vscode.commands.registerCommand('gloss.openMerrilyItem', openMerrilyItem)
	);

	// Listen for document opens
	context.subscriptions.push(
		vscode.workspace.onDidOpenTextDocument(onDocumentOpen)
	);

	// Listen for configuration changes
	context.subscriptions.push(
		vscode.workspace.onDidChangeConfiguration(e => {
			if (e.affectsConfiguration('gloss')) {
				updateStatusBar();
				merrilyTreeProvider.refresh();
			}
		})
	);

	console.log('Gloss extension activated');
}

export function deactivate() {
	console.log('Gloss extension deactivated');
}

// === Core Reading Mode ===

async function onDocumentOpen(document: vscode.TextDocument) {
	const config = vscode.workspace.getConfiguration('gloss');
	
	if (!config.get<boolean>('enabled', true)) {
		return;
	}

	if (document.languageId !== 'markdown') {
		return;
	}

	// Check if file matches patterns
	if (!shouldOpenInReadingMode(document.uri)) {
		return;
	}

	// Small delay to let VS Code finish opening the file
	await delay(50);

	// Open in preview mode
	await openPreview(document.uri);
}

function shouldOpenInReadingMode(uri: vscode.Uri): boolean {
	const config = vscode.workspace.getConfiguration('gloss');
	const patterns = config.get<string[]>('patterns', ['**/*.md', '**/*.markdown']);
	const excludePatterns = config.get<string[]>('exclude', []);

	const relativePath = vscode.workspace.asRelativePath(uri);

	// Check exclude patterns first
	for (const pattern of excludePatterns) {
		if (minimatch(relativePath, pattern)) {
			return false;
		}
	}

	// Check include patterns
	for (const pattern of patterns) {
		if (minimatch(relativePath, pattern)) {
			return true;
		}
	}

	return false;
}

async function openPreview(uri: vscode.Uri) {
	const config = vscode.workspace.getConfiguration('gloss');
	
	// Open in custom Gloss Reader panel
	GlossReaderPanel.createOrShow(extensionUri, uri);

	// Close source tab if configured
	if (config.get<boolean>('closeSourceTab', true)) {
		await closeSourceTab(uri);
	}

	// Enter Zen Mode if configured
	if (config.get<boolean>('zenMode', false)) {
		await vscode.commands.executeCommand('workbench.action.toggleZenMode');
	}
}

async function closeSourceTab(uri: vscode.Uri) {
	// Find and close the source editor tab
	const tabs = vscode.window.tabGroups.all
		.flatMap(group => group.tabs)
		.filter(tab => {
			if (tab.input instanceof vscode.TabInputText) {
				return tab.input.uri.toString() === uri.toString();
			}
			return false;
		});

	for (const tab of tabs) {
		await vscode.window.tabGroups.close(tab);
	}
}

// === Commands ===

async function editCurrentFile() {
	// The GlossReaderPanel handles its own "Edit" button
	// This command is kept for keyboard shortcut compatibility
	// If there's an active Gloss panel, it will handle Cmd+Shift+E internally
	vscode.window.showInformationMessage('Use the Edit button in the Gloss Reader toolbar');
}

function toggleEnabled() {
	const config = vscode.workspace.getConfiguration('gloss');
	const current = config.get<boolean>('enabled', true);
	config.update('enabled', !current, vscode.ConfigurationTarget.Global);
	updateStatusBar();
	
	vscode.window.showInformationMessage(
		`Gloss reading mode ${!current ? 'enabled' : 'disabled'}`
	);
}

async function openInReadingMode(uri?: vscode.Uri) {
	if (!uri) {
		const editor = vscode.window.activeTextEditor;
		if (editor && editor.document.languageId === 'markdown') {
			uri = editor.document.uri;
		}
	}

	if (uri) {
		await openPreview(uri);
	}
}

// === Merrily Integration ===

async function configureMerrilyFolder() {
	const options: vscode.OpenDialogOptions = {
		canSelectFiles: false,
		canSelectFolders: true,
		canSelectMany: false,
		openLabel: 'Select Operations Folder',
		title: 'Select your operations documents folder'
	};

	const result = await vscode.window.showOpenDialog(options);
	
	if (result && result[0]) {
		const config = vscode.workspace.getConfiguration('gloss');
		await config.update('merrily.localFolder', result[0].fsPath, vscode.ConfigurationTarget.Global);
		merrilyTreeProvider.refresh();
		vscode.window.showInformationMessage(`Merrily folder set to: ${result[0].fsPath}`);
	}
}

async function connectMerrilyApi() {
	const url = await vscode.window.showInputBox({
		prompt: 'Enter your Merrily API URL',
		placeHolder: 'http://localhost:3000',
		value: 'http://localhost:3000'
	});

	if (!url) {
		return;
	}

	const token = await vscode.window.showInputBox({
		prompt: 'Enter your Merrily API token (or leave empty to login)',
		password: true
	});

	const config = vscode.workspace.getConfiguration('gloss');
	await config.update('merrily.apiUrl', url, vscode.ConfigurationTarget.Global);
	
	if (token) {
		// Store token securely
		await vscode.workspace.getConfiguration('gloss').update(
			'merrily.apiToken', 
			token, 
			vscode.ConfigurationTarget.Global
		);
	}

	merrilyTreeProvider.refresh();
	vscode.window.showInformationMessage('Connected to Merrily API');
}

async function disconnectMerrilyApi() {
	const config = vscode.workspace.getConfiguration('gloss');
	await config.update('merrily.apiUrl', undefined, vscode.ConfigurationTarget.Global);
	await config.update('merrily.apiToken', undefined, vscode.ConfigurationTarget.Global);
	merrilyTreeProvider.refresh();
	vscode.window.showInformationMessage('Disconnected from Merrily API');
}

async function openMerrilyItem(item: { uri?: vscode.Uri; content?: string; title?: string }) {
	if (item.uri) {
		// Local file - open in Gloss Reader
		GlossReaderPanel.createOrShow(extensionUri, item.uri);
	} else if (item.content) {
		// API content - create a temp file and open in Gloss Reader
		// For now, use the built-in preview for virtual content
		const doc = await vscode.workspace.openTextDocument({
			content: item.content,
			language: 'markdown'
		});
		await vscode.commands.executeCommand('markdown.showPreview', doc.uri);
	}
}

// === Status Bar ===

function updateStatusBar() {
	const config = vscode.workspace.getConfiguration('gloss');
	
	if (!config.get<boolean>('showStatusBar', true)) {
		statusBarItem.hide();
		return;
	}

	const enabled = config.get<boolean>('enabled', true);
	statusBarItem.text = enabled ? '$(book) Gloss' : '$(book) Gloss (off)';
	statusBarItem.tooltip = enabled 
		? 'Gloss reading mode enabled - click to disable' 
		: 'Gloss reading mode disabled - click to enable';
	statusBarItem.show();
}

// === Utilities ===

function delay(ms: number): Promise<void> {
	return new Promise(resolve => setTimeout(resolve, ms));
}
