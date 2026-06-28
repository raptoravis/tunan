import type { Plugin } from '@opencode-ai/plugin';
import { ChangedFilesStore } from './lib/changed-files-store.js';

const ECC_HOOK_PROFILE = process.env.ECC_HOOK_PROFILE || 'standard';
const ECC_DISABLED_HOOKS = process.env.ECC_DISABLED_HOOKS?.split(',') || [];

function isHookDisabled(hookId: string): boolean {
  return ECC_DISABLED_HOOKS.includes(hookId);
}

function shouldRunInProfile(level: 'minimal' | 'standard' | 'strict'): boolean {
  const profileOrder = { minimal: 0, standard: 1, strict: 2 };
  return profileOrder[ECC_HOOK_PROFILE as keyof typeof profileOrder] >= profileOrder[level];
}

const store = new ChangedFilesStore();

export const TunanHooksPlugin: Plugin = {
  name: 'tunan-hooks',
  version: '1.0.0',

  hooks: {
    'tool.execute.before': async (ctx) => {
      if (isHookDisabled('pre:tool:security')) return;

      const { tool, input } = ctx;
      
      if (tool === 'bash' && shouldRunInProfile('strict')) {
        const cmd = input.command || '';
        if (cmd.includes('git push') && !cmd.includes('--dry-run')) {
          console.log('⚠️  Reminder: Review changes before pushing to remote.');
        }
      }

      if (tool === 'write' || tool === 'edit') {
        const content = input.content || '';
        const secretPatterns = [
          /api[_-]?key\s*[=:]\s*['"][^'"]+['"]/i,
          /password\s*[=:]\s*['"][^'"]+['"]/i,
          /token\s*[=:]\s*['"][^'"]+['"]/i,
          /secret\s*[=:]\s*['"][^'"]+['"]/i,
        ];
        
        for (const pattern of secretPatterns) {
          if (pattern.test(content)) {
            console.log('⚠️  Warning: Potential hardcoded secret detected in file.');
            break;
          }
        }
      }
    },

    'tool.execute.after': async (ctx) => {
      if (isHookDisabled('post:tool:format')) return;

      const { tool, input, output } = ctx;
      
      if ((tool === 'write' || tool === 'edit') && shouldRunInProfile('strict')) {
        const filePath = input.file_path || input.filePath;
        if (filePath && (filePath.endsWith('.ts') || filePath.endsWith('.tsx') || filePath.endsWith('.js') || filePath.endsWith('.jsx'))) {
          try {
            const { execSync } = await import('child_process');
            execSync(`npx prettier --write "${filePath}"`, { stdio: 'ignore' });
          } catch {
            // Prettier not available, skip
          }
        }
      }

      if ((tool === 'write' || tool === 'edit') && shouldRunInProfile('standard')) {
        const filePath = input.file_path || input.filePath;
        if (filePath && (filePath.endsWith('.ts') || filePath.endsWith('.tsx'))) {
          try {
            const { execSync } = await import('child_process');
            execSync('npx tsc --noEmit', { stdio: 'ignore' });
          } catch {
            // TypeScript check failed, but don't block
          }
        }
      }
    },

    'session.created': async (ctx) => {
      if (isHookDisabled('session:context')) return;
      
      store.clear();
      console.log('🔧 Tunan session started. Use /tunan:brainstorm to begin.');
    },

    'session.idle': async (ctx) => {
      if (isHookDisabled('session:idle')) return;

      if (shouldRunInProfile('standard')) {
        const changes = store.getChanges();
        const jsFiles = changes.filter(f => 
          f.path.endsWith('.js') || f.path.endsWith('.ts') || f.path.endsWith('.tsx')
        );
        
        for (const file of jsFiles) {
          try {
            const { readFileSync } = await import('fs');
            const content = readFileSync(file.path, 'utf-8');
            if (content.includes('console.log(')) {
              console.log(`⚠️  ${file.path} contains console.log statements.`);
            }
          } catch {
            // File not readable
          }
        }
      }
    },

    'file.edited': async (ctx) => {
      if (isHookDisabled('file:edited')) return;

      const { file_path } = ctx;
      store.recordChange(file_path, 'modified');
    },

    'shell.env': async (ctx) => {
      return {
        TUNAN_SESSION: 'true',
        TUNAN_HOOK_PROFILE: ECC_HOOK_PROFILE,
      };
    },

    'permission.ask': async (ctx) => {
      if (isHookDisabled('permission:auto')) return;

      const { tool, input } = ctx;
      
      const autoApproveTools = ['read', 'glob', 'grep', 'codegraph_search', 'codegraph_context'];
      if (autoApproveTools.includes(tool)) {
        return { approve: true };
      }

      if (tool === 'bash') {
        const cmd = input.command || '';
        const safePatterns = [
          /^git status/,
          /^git log/,
          /^git diff/,
          /^ls/,
          /^pwd/,
          /^cat /,
          /^npx prettier/,
          /^npx eslint/,
          /^npm test/,
          /^yarn test/,
          /^pnpm test/,
        ];
        
        for (const pattern of safePatterns) {
          if (pattern.test(cmd)) {
            return { approve: true };
          }
        }
      }

      return { approve: false };
    },
  },
};
