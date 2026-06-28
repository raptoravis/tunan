import { defineTool } from '@opencode-ai/plugin/tool';
import { execSync } from 'child_process';

export const runTests = defineTool({
  name: 'run-tests',
  description: 'Run test suite with options',
  parameters: {
    pattern: {
      type: 'string',
      description: 'Test file pattern to run',
      required: false,
    },
    coverage: {
      type: 'boolean',
      description: 'Enable coverage collection',
      required: false,
      default: false,
    },
    watch: {
      type: 'boolean',
      description: 'Run in watch mode',
      required: false,
      default: false,
    },
    updateSnapshots: {
      type: 'boolean',
      description: 'Update snapshots',
      required: false,
      default: false,
    },
  },
  async execute(params) {
    const { pattern, coverage, watch, updateSnapshots } = params;
    
    let command = '';
    
    // Detect test runner
    try {
      execSync('npx jest --version', { stdio: 'ignore' });
      command = 'npx jest';
    } catch {
      try {
        execSync('npx vitest --version', { stdio: 'ignore' });
        command = 'npx vitest run';
      } catch {
        try {
          execSync('npm test', { stdio: 'ignore' });
          command = 'npm test';
        } catch {
          return { error: 'No test runner detected. Install jest or vitest.' };
        }
      }
    }
    
    // Build command
    if (pattern) {
      command += ` ${pattern}`;
    }
    
    if (coverage) {
      command += ' --coverage';
    }
    
    if (watch) {
      command += ' --watch';
    }
    
    if (updateSnapshots) {
      command += ' --updateSnapshot';
    }
    
    try {
      const output = execSync(command, { 
        encoding: 'utf-8',
        stdio: 'pipe',
      });
      
      return { 
        success: true, 
        output,
        command,
      };
    } catch (error) {
      return { 
        success: false, 
        error: error.message,
        command,
      };
    }
  },
});
