import * as vscode from 'vscode';

// Types matching Merrily API responses
export interface Pitch {
  id: string;
  title: string;
  status: 'raw' | 'shaped' | 'ready' | 'bet' | 'archived';
  problem?: string;
  solution?: string;
  appetite?: string;
  rabbit_holes?: string;
  no_gos?: string;
  created_at: string;
  updated_at: string;
}

export interface Cycle {
  id: string;
  name: string;
  status: 'planning' | 'betting' | 'building' | 'cooldown' | 'complete';
  start_date: string;
  end_date: string;
  description?: string;
  budget?: number;
  created_at: string;
  updated_at: string;
}

export interface Retrospective {
  id: string;
  cycle_id: string;
  cycle_name?: string;
  status: 'draft' | 'published';
  summary?: string;
  went_well?: string;
  went_poorly?: string;
  improvements?: string;
  created_at: string;
  updated_at: string;
}

export interface Project {
  id: string;
  name: string;
  status: 'active' | 'shipped' | 'abandoned';
  cycle_id: string;
  pitch_id?: string;
  created_at: string;
  updated_at: string;
}

export class MerrilyApiClient {
  private context: vscode.ExtensionContext;

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
  }

  private getConfig() {
    return vscode.workspace.getConfiguration('gloss');
  }

  private getApiUrl(): string | undefined {
    return this.getConfig().get<string>('merrily.apiUrl');
  }

  private getApiToken(): string | undefined {
    return this.getConfig().get<string>('merrily.apiToken');
  }

  private async fetch<T>(endpoint: string): Promise<T> {
    const baseUrl = this.getApiUrl();
    const token = this.getApiToken();

    if (!baseUrl) {
      throw new Error('Merrily API URL not configured');
    }

    const url = `${baseUrl}${endpoint}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    try {
      const response = await fetch(url, { headers });

      if (!response.ok) {
        throw new Error(`API error: ${response.status} ${response.statusText}`);
      }

      return (await response.json()) as T;
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`Failed to fetch from Merrily: ${error.message}`);
      }
      throw error;
    }
  }

  async isConnected(): Promise<boolean> {
    const apiUrl = this.getApiUrl();
    if (!apiUrl) {
      return false;
    }

    try {
      // Try a simple health check or get current user
      await this.fetch('/api/me');
      return true;
    } catch {
      return false;
    }
  }

  async getPitches(): Promise<Pitch[]> {
    try {
      const response = await this.fetch<{ pitches: Pitch[] }>('/api/pitches');
      return response.pitches || [];
    } catch (error) {
      console.error('Error fetching pitches:', error);
      return [];
    }
  }

  async getCycles(): Promise<Cycle[]> {
    try {
      const response = await this.fetch<{ cycles: Cycle[] }>('/api/cycles');
      return response.cycles || [];
    } catch (error) {
      console.error('Error fetching cycles:', error);
      return [];
    }
  }

  async getRetrospectives(): Promise<Retrospective[]> {
    try {
      // Get all cycles first to get their retrospectives
      const cycles = await this.getCycles();
      const retros: Retrospective[] = [];

      for (const cycle of cycles) {
        try {
          const response = await this.fetch<{ retrospective: Retrospective }>(
            `/api/cycles/${cycle.id}/retrospective`
          );
          if (response.retrospective) {
            retros.push({
              ...response.retrospective,
              cycle_name: cycle.name
            });
          }
        } catch {
          // Cycle may not have a retrospective
        }
      }

      return retros;
    } catch (error) {
      console.error('Error fetching retrospectives:', error);
      return [];
    }
  }

  async getProjects(): Promise<Project[]> {
    try {
      const response = await this.fetch<{ projects: Project[] }>('/api/projects');
      return response.projects || [];
    } catch (error) {
      console.error('Error fetching projects:', error);
      return [];
    }
  }

  async getPitch(id: string): Promise<Pitch | null> {
    try {
      const response = await this.fetch<{ pitch: Pitch }>(`/api/pitches/${id}`);
      return response.pitch || null;
    } catch (error) {
      console.error('Error fetching pitch:', error);
      return null;
    }
  }

  async getCycle(id: string): Promise<Cycle | null> {
    try {
      const response = await this.fetch<{ cycle: Cycle }>(`/api/cycles/${id}`);
      return response.cycle || null;
    } catch (error) {
      console.error('Error fetching cycle:', error);
      return null;
    }
  }
}
