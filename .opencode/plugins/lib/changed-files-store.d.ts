export interface FileChange {
    path: string;
    type: 'added' | 'modified' | 'deleted';
    timestamp: number;
}
export declare class ChangedFilesStore {
    private changes;
    recordChange(path: string, type: FileChange['type']): void;
    getChanges(): FileChange[];
    getChangedPaths(): string[];
    buildTree(): Record<string, unknown>;
    clear(): void;
}
//# sourceMappingURL=changed-files-store.d.ts.map