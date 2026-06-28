import { tool } from '@opencode-ai/plugin/tool';
import { execSync } from 'child_process';

export const gitSummary = tool({
  name: 'git-summary',
  description: 'Generate git status summary',
  parameters: {
    depth: {
      type: 'number',
      description: 'Number of recent commits to show',
      required: false,
      default: 5,
    },
    includeDiff: {
      type: 'boolean',
      description: 'Include diff stats',
      required: false,
      default: true,
    },
    baseBranch: {
      type: 'string',
      description: 'Base branch to compare against',
      required: false,
      default: 'main',
    },
  },
  async execute(params) {
    const { depth, includeDiff, baseBranch } = params;
    
    const summary: Record<string, unknown> = {};
    
    try {
      // Branch info
      const branch = execSync('git branch --show-current', { encoding: 'utf-8' }).trim();
      summary.branch = branch;
      
      // Status
      const status = execSync('git status --porcelain', { encoding: 'utf-8' }).trim();
      summary.status = {
        modified: status.split('\n').filter(l => l.startsWith(' M')).length,
        added: status.split('\n').filter(l => l.startsWith('A ')).length,
        deleted: status.split('\n').filter(l => l.startsWith(' D')).length,
        untracked: status.split('\n').filter(l => l.startsWith('??')).length,
      };
      
      // Recent commits
      const commits = execSync(
        `git log --oneline -${depth}`,
        { encoding: 'utf-8' }
      ).trim().split('\n');
      summary.recentCommits = commits;
      
      // Diff stats
      if (includeDiff) {
        try {
          const diff = execSync(
            `git diff ${baseBranch}...HEAD --stat`,
            { encoding: 'utf-8' }
          ).trim();
          summary.diffStats = diff;
        } catch {
          summary.diffStats = 'Unable to get diff stats';
        }
      }
      
      // Remote info
      try {
        const remote = execSync('git remote -v', { encoding: 'utf-8' }).trim();
        summary.remote = remote;
      } catch {
        summary.remote = 'No remote configured';
      }
      
      return summary;
    } catch (error) {
      return { error: error.message };
    }
  },
});
