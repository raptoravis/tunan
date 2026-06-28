export class ChangedFilesStore {
    changes = [];
    recordChange(path, type) {
        const existing = this.changes.find(c => c.path === path);
        if (existing) {
            existing.type = type;
            existing.timestamp = Date.now();
        }
        else {
            this.changes.push({ path, type, timestamp: Date.now() });
        }
    }
    getChanges() {
        return [...this.changes];
    }
    getChangedPaths() {
        return this.changes.map(c => c.path);
    }
    buildTree() {
        const tree = {};
        for (const change of this.changes) {
            const parts = change.path.split(/[/\\]/);
            let current = tree;
            for (let i = 0; i < parts.length - 1; i++) {
                if (!current[parts[i]]) {
                    current[parts[i]] = {};
                }
                current = current[parts[i]];
            }
            current[parts[parts.length - 1]] = {
                type: change.type,
                timestamp: change.timestamp,
            };
        }
        return tree;
    }
    clear() {
        this.changes = [];
    }
}
//# sourceMappingURL=changed-files-store.js.map