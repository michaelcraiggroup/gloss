import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { MerrilyApiClient, Pitch, Cycle, Retrospective } from './apiClient';

export class MerrilyTreeProvider implements vscode.TreeDataProvider<MerrilyTreeItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<
    MerrilyTreeItem | undefined | null | void
  >();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  constructor(private apiClient: MerrilyApiClient) {}

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: MerrilyTreeItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: MerrilyTreeItem): Promise<MerrilyTreeItem[]> {
    if (!element) {
      // Root level - show categories
      return this.getRootItems();
    }

    // Child items based on category
    switch (element.contextValue) {
      case 'category-local':
        return this.getLocalFolderItems(element.resourcePath);
      case 'category-pitches':
        return this.getPitchItems();
      case 'category-cycles':
        return this.getCycleItems();
      case 'category-retrospectives':
        return this.getRetrospectiveItems();
      case 'folder':
        return this.getLocalFolderItems(element.resourcePath);
      default:
        return [];
    }
  }

  private async getRootItems(): Promise<MerrilyTreeItem[]> {
    const items: MerrilyTreeItem[] = [];
    const config = vscode.workspace.getConfiguration('gloss');

    // Local folder section
    const localFolder = config.get<string>('merrily.localFolder');
    if (localFolder && fs.existsSync(localFolder)) {
      items.push(
        new MerrilyTreeItem(
          '📁 Local Documents',
          vscode.TreeItemCollapsibleState.Expanded,
          'category-local',
          localFolder
        )
      );
    } else {
      items.push(
        new MerrilyTreeItem(
          '📁 Configure Local Folder...',
          vscode.TreeItemCollapsibleState.None,
          'configure-local',
          undefined,
          {
            command: 'gloss.configureMerrilyFolder',
            title: 'Configure Folder'
          }
        )
      );
    }

    // API sections (if connected)
    const apiUrl = config.get<string>('merrily.apiUrl');
    if (apiUrl) {
      items.push(
        new MerrilyTreeItem(
          '📝 Pitches',
          vscode.TreeItemCollapsibleState.Collapsed,
          'category-pitches'
        )
      );
      items.push(
        new MerrilyTreeItem(
          '🔄 Cycles',
          vscode.TreeItemCollapsibleState.Collapsed,
          'category-cycles'
        )
      );
      items.push(
        new MerrilyTreeItem(
          '📊 Retrospectives',
          vscode.TreeItemCollapsibleState.Collapsed,
          'category-retrospectives'
        )
      );
    } else {
      items.push(
        new MerrilyTreeItem(
          '🔌 Connect to Merrily API...',
          vscode.TreeItemCollapsibleState.None,
          'configure-api',
          undefined,
          {
            command: 'gloss.connectMerrilyApi',
            title: 'Connect API'
          }
        )
      );
    }

    return items;
  }

  private async getLocalFolderItems(folderPath?: string): Promise<MerrilyTreeItem[]> {
    if (!folderPath) {
      return [];
    }

    try {
      const entries = fs.readdirSync(folderPath, { withFileTypes: true });
      const items: MerrilyTreeItem[] = [];

      // Sort: folders first, then files, alphabetically
      const sorted = entries.sort((a, b) => {
        if (a.isDirectory() && !b.isDirectory()) return -1;
        if (!a.isDirectory() && b.isDirectory()) return 1;
        return a.name.localeCompare(b.name);
      });

      for (const entry of sorted) {
        // Skip hidden files and common non-doc folders
        if (entry.name.startsWith('.') || entry.name === 'node_modules') {
          continue;
        }

        const fullPath = path.join(folderPath, entry.name);

        if (entry.isDirectory()) {
          items.push(
            new MerrilyTreeItem(
              `📂 ${entry.name}`,
              vscode.TreeItemCollapsibleState.Collapsed,
              'folder',
              fullPath
            )
          );
        } else if (entry.name.endsWith('.md') || entry.name.endsWith('.mdx')) {
          const icon = this.getDocumentIcon(entry.name, folderPath);
          items.push(
            new MerrilyTreeItem(
              `${icon} ${entry.name.replace(/\.mdx?$/, '')}`,
              vscode.TreeItemCollapsibleState.None,
              'document',
              fullPath,
              {
                command: 'gloss.openMerrilyItem',
                title: 'Open Document',
                arguments: [{ uri: vscode.Uri.file(fullPath) }]
              }
            )
          );
        }
      }

      return items;
    } catch (error) {
      console.error('Error reading folder:', error);
      return [];
    }
  }

  private getDocumentIcon(filename: string, folderPath: string): string {
    const lowerName = filename.toLowerCase();
    const folderName = path.basename(folderPath).toLowerCase();

    // Icon based on folder context
    if (folderName === 'pitches' || lowerName.includes('pitch')) return '💡';
    if (folderName === 'retrospectives' || lowerName.includes('retro')) return '📊';
    if (folderName === 'strategies' || lowerName.includes('strategy')) return '🎯';
    if (folderName === 'principles' || lowerName.includes('principle')) return '⚖️';
    if (folderName === 'audits' || lowerName.includes('audit')) return '🔍';
    if (folderName === 'flashcards' || lowerName.includes('flashcard')) return '🃏';
    if (folderName === 'templates' || lowerName.includes('template')) return '📋';
    if (folderName === 'decisions' || lowerName.includes('decision') || lowerName.includes('adr'))
      return '⚡';
    if (folderName === 'research' || lowerName.includes('brief')) return '🔬';
    if (lowerName.includes('readme')) return '📖';
    if (lowerName.includes('changelog')) return '📝';
    if (lowerName.includes('plan')) return '🗺️';

    return '📄';
  }

  private async getPitchItems(): Promise<MerrilyTreeItem[]> {
    try {
      const pitches = await this.apiClient.getPitches();
      return pitches.map(
        (pitch) =>
          new MerrilyTreeItem(
            `💡 ${pitch.title}`,
            vscode.TreeItemCollapsibleState.None,
            'pitch',
            undefined,
            {
              command: 'gloss.openMerrilyItem',
              title: 'Open Pitch',
              arguments: [
                {
                  content: this.formatPitchAsMarkdown(pitch),
                  title: pitch.title
                }
              ]
            },
            pitch.status
          )
      );
    } catch (error) {
      return [
        new MerrilyTreeItem(
          '⚠️ Failed to load pitches',
          vscode.TreeItemCollapsibleState.None,
          'error'
        )
      ];
    }
  }

  private async getCycleItems(): Promise<MerrilyTreeItem[]> {
    try {
      const cycles = await this.apiClient.getCycles();
      return cycles.map(
        (cycle) =>
          new MerrilyTreeItem(
            `🔄 ${cycle.name}`,
            vscode.TreeItemCollapsibleState.None,
            'cycle',
            undefined,
            {
              command: 'gloss.openMerrilyItem',
              title: 'Open Cycle',
              arguments: [
                {
                  content: this.formatCycleAsMarkdown(cycle),
                  title: cycle.name
                }
              ]
            },
            cycle.status
          )
      );
    } catch (error) {
      return [
        new MerrilyTreeItem(
          '⚠️ Failed to load cycles',
          vscode.TreeItemCollapsibleState.None,
          'error'
        )
      ];
    }
  }

  private async getRetrospectiveItems(): Promise<MerrilyTreeItem[]> {
    try {
      const retros = await this.apiClient.getRetrospectives();
      return retros.map(
        (retro) =>
          new MerrilyTreeItem(
            `📊 ${retro.cycle_name || 'Retrospective'}`,
            vscode.TreeItemCollapsibleState.None,
            'retrospective',
            undefined,
            {
              command: 'gloss.openMerrilyItem',
              title: 'Open Retrospective',
              arguments: [
                {
                  content: this.formatRetroAsMarkdown(retro),
                  title: `Retrospective: ${retro.cycle_name}`
                }
              ]
            },
            retro.status
          )
      );
    } catch (error) {
      return [
        new MerrilyTreeItem(
          '⚠️ Failed to load retrospectives',
          vscode.TreeItemCollapsibleState.None,
          'error'
        )
      ];
    }
  }

  // === Markdown Formatters ===

  private formatPitchAsMarkdown(pitch: Pitch): string {
    return `# ${pitch.title}

**Status:** ${pitch.status}
**Appetite:** ${pitch.appetite || 'Not set'}

## Problem

${pitch.problem || '_No problem statement_'}

## Solution

${pitch.solution || '_No solution described_'}

## Rabbit Holes

${pitch.rabbit_holes || '_None identified_'}

## No-Gos

${pitch.no_gos || '_None specified_'}
`;
  }

  private formatCycleAsMarkdown(cycle: Cycle): string {
    return `# ${cycle.name}

**Status:** ${cycle.status}
**Start:** ${cycle.start_date}
**End:** ${cycle.end_date}

## Description

${cycle.description || '_No description_'}

## Budget

${cycle.budget ? `$${cycle.budget.toLocaleString()}` : '_Not set_'}
`;
  }

  private formatRetroAsMarkdown(retro: Retrospective): string {
    return `# Retrospective: ${retro.cycle_name}

**Status:** ${retro.status}

## Summary

${retro.summary || '_No summary_'}

## What Went Well

${retro.went_well || '_Not filled in_'}

## What Went Poorly

${retro.went_poorly || '_Not filled in_'}

## Improvements

${retro.improvements || '_Not filled in_'}
`;
  }
}

export class MerrilyTreeItem extends vscode.TreeItem {
  constructor(
    public readonly label: string,
    public readonly collapsibleState: vscode.TreeItemCollapsibleState,
    public readonly contextValue: string,
    public readonly resourcePath?: string,
    public readonly command?: vscode.Command,
    public readonly status?: string
  ) {
    super(label, collapsibleState);

    this.contextValue = contextValue;
    this.command = command;

    // Add status badge as description
    if (status) {
      this.description = status;
    }

    // Set tooltip
    if (resourcePath) {
      this.tooltip = resourcePath;
    }
  }
}
