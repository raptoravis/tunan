export interface FileChange {
  path: string;
  type: 'added' | 'modified' | 'deleted';
  timestamp: number;
}

export class ChangedFilesStore {
  private changes: FileChange[] = [];

  recordChange(path: string, type: FileChange['type']): void {
    const existing = this.changes.find(c => c.path === path);
    if (existing) {
      existing.type = type;
      existing.timestamp = Date.now();
    } else {
      this.changes.push({ path, type, timestamp: Date.now() });
    }
  }

  getChanges(): FileChange[] {
    return [...this.changes];
  }

  getChangedPaths(): string[] {
    return this.changes.map(c => c.path);
  }

  buildTree(): Record<string, unknown> {
    const tree: Record<string, unknown> = {};
    
    for (const change of this.changes) {
      const parts = change.path.split(/[/\\]/);
      let current = tree;
      
      for (let i = 0; i < parts.length - 1; i++) {
        if (!current[parts[i]]) {
          current[parts[i]] = {};
        }
        current = current[parts[i]] as Record<string, unknown>;
      }
      
      current[parts[parts.length - 1]] = {
        type: change.type,
        timestamp: change.timestamp,
      };
    }
    
    return tree;
  }

  clear(): void {
    this.changes = [];
  }
}
