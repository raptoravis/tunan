import { tool } from '@opencode-ai/plugin/tool';
import { execSync } from 'child_process';

export const changedFiles = tool({
  name: 'changed-files',
  description: 'List files changed in session',
  parameters: {
    filter: {
      type: 'string',
      description: 'Filter by change type (all, modified, added, deleted)',
      required: false,
      default: 'all',
    },
    format: {
      type: 'string',
      description: 'Output format (list, tree, json)',
      required: false,
      default: 'list',
    },
  },
  async execute(params) {
    const { filter, format } = params;
    
    try {
      // Get changed files
      let command = 'git diff --name-status';
      
      if (filter === 'added') {
        command += ' --diff-filter=A';
      } else if (filter === 'modified') {
        command += ' --diff-filter=M';
      } else if (filter === 'deleted') {
        command += ' --diff-filter=D';
      }
      
      const output = execSync(command, { encoding: 'utf-8' }).trim();
      
      if (!output) {
        return { files: [], message: 'No changed files detected' };
      }
      
      const files = output.split('\n').map(line => {
        const [status, ...pathParts] = line.split('\t');
        return {
          status: status.trim(),
          path: pathParts.join('\t'),
        };
      });
      
      // Format output
      if (format === 'json') {
        return { files };
      }
      
      if (format === 'tree') {
        const tree: Record<string, unknown> = {};
        for (const file of files) {
          const parts = file.path.split('/');
          let current = tree;
          for (let i = 0; i < parts.length - 1; i++) {
            if (!current[parts[i]]) {
              current[parts[i]] = {};
            }
            current = current[parts[i]] as Record<string, unknown>;
          }
          current[parts[parts.length - 1]] = file.status;
        }
        return { tree };
      }
      
      // List format (default)
      const fileList = files.map(f => `${f.status}\t${f.path}`).join('\n');
      return { files, formatted: fileList };
    } catch (error) {
      return { error: error.message };
    }
  },
});
