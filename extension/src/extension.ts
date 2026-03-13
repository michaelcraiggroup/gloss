import * as vscode from 'vscode';
import { minimatch } from 'minimatch';
import { GlossReaderPanel } from './reader/GlossReaderPanel';

let statusBarItem: vscode.StatusBarItem;
let extensionUri: vscode.Uri;

export function activate(context: vscode.ExtensionContext) {
  console.log('Gloss extension activating...');

  // Store extension URI for webview resources
  extensionUri = context.extensionUri;

  // Status bar indicator
  statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusBarItem.command = 'gloss.toggleEnabled';
  context.subscriptions.push(statusBarItem);
  updateStatusBar();

  // Register commands
  context.subscriptions.push(
    vscode.commands.registerCommand('gloss.editFile', editCurrentFile),
    vscode.commands.registerCommand('gloss.toggleEnabled', toggleEnabled),
    vscode.commands.registerCommand('gloss.openInReadingMode', openInReadingMode),
    vscode.commands.registerCommand('gloss.print', printCurrentPanel)
  );

  // Listen for document opens
  context.subscriptions.push(vscode.workspace.onDidOpenTextDocument(onDocumentOpen));

  // Catch reopens of cached documents (onDidOpenTextDocument won't fire again)
  context.subscriptions.push(
    vscode.window.onDidChangeActiveTextEditor(async (editor) => {
      if (!editor) return;
      const doc = editor.document;
      if (doc.languageId !== 'markdown') return;
      const config = vscode.workspace.getConfiguration('gloss');
      if (!config.get<boolean>('enabled', true)) return;
      const uriString = doc.uri.toString();
      if (GlossReaderPanel.recentlyEdited.has(uriString)) return;
      if (GlossReaderPanel.currentPanels.has(uriString)) return;
      if (!shouldOpenInReadingMode(doc.uri)) return;
      await delay(50);
      await openPreview(doc.uri);
    })
  );

  // Listen for configuration changes
  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration('gloss')) {
        updateStatusBar();
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
    .flatMap((group) => group.tabs)
    .filter((tab) => {
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
  vscode.window.showInformationMessage('Use the Edit button in the Gloss Reader toolbar');
}

function toggleEnabled() {
  const config = vscode.workspace.getConfiguration('gloss');
  const current = config.get<boolean>('enabled', true);
  config.update('enabled', !current, vscode.ConfigurationTarget.Global);
  updateStatusBar();

  vscode.window.showInformationMessage(`Gloss reading mode ${!current ? 'enabled' : 'disabled'}`);
}

function printCurrentPanel() {
  // Find the active (visible) Gloss panel and trigger print
  for (const panel of GlossReaderPanel.currentPanels.values()) {
    if (panel.isActive) {
      panel.print();
      return;
    }
  }
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
  return new Promise((resolve) => setTimeout(resolve, ms));
}
