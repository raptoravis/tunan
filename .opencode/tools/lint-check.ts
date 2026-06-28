import { tool } from '@opencode-ai/plugin/tool';
import { execSync } from 'child_process';
import { existsSync } from 'fs';

export const lintCheck = tool({
  name: 'lint-check',
  description: 'Run linter and check for issues',
  parameters: {
    target: {
      type: 'string',
      description: 'Target to lint (file, directory, or "all")',
      required: false,
      default: 'all',
    },
    fix: {
      type: 'boolean',
      description: 'Attempt to auto-fix issues',
      required: false,
      default: false,
    },
    linter: {
      type: 'string',
      description: 'Linter to use (eslint, biome, stylelint)',
      required: false,
    },
  },
  async execute(params) {
    const { target, fix, linter } = params;
    
    // Detect linter
    let detectedLinter = linter;
    
    if (!detectedLinter) {
      if (existsSync('.eslintrc.js') || existsSync('eslint.config.js')) {
        detectedLinter = 'eslint';
      } else if (existsSync('biome.json')) {
        detectedLinter = 'biome';
      } else if (existsSync('.stylelintrc.js') || existsSync('stylelint.config.js')) {
        detectedLinter = 'stylelint';
      } else {
        detectedLinter = 'eslint';
      }
    }
    
    // Build command
    let command = '';
    const targetPath = target === 'all' ? '.' : target;
    
    switch (detectedLinter) {
      case 'eslint':
        command = fix
          ? `npx eslint --fix ${targetPath}`
          : `npx eslint ${targetPath}`;
        break;
      case 'biome':
        command = fix
          ? `npx biome check --write ${targetPath}`
          : `npx biome check ${targetPath}`;
        break;
      case 'stylelint':
        command = fix
          ? `npx stylelint --fix ${targetPath}`
          : `npx stylelint ${targetPath}`;
        break;
      default:
        return { error: `Unknown linter: ${detectedLinter}` };
    }
    
    try {
      const output = execSync(command, { 
        encoding: 'utf-8',
        stdio: 'pipe',
      });
      
      return { 
        success: true, 
        linter: detectedLinter,
        command,
        output,
        issues: 0,
      };
    } catch (error) {
      const output = error.stdout || error.stderr || error.message;
      
      // Count issues
      const issueMatches = output.match(/\d+ problem/g);
      const issueCount = issueMatches 
        ? parseInt(issueMatches[0]) 
        : output.split('\n').filter((line: string) => line.includes('error') || line.includes('warning')).length;
      
      return { 
        success: false, 
        linter: detectedLinter,
        command,
        output,
        issues: issueCount,
      };
    }
  },
});
