import { tool } from '@opencode-ai/plugin/tool';
import { execSync } from 'child_process';
import { readFileSync } from 'fs';

export const checkCoverage = tool({
  name: 'check-coverage',
  description: 'Check test coverage',
  parameters: {
    threshold: {
      type: 'number',
      description: 'Minimum coverage threshold (0-100)',
      required: false,
      default: 80,
    },
    showUncovered: {
      type: 'boolean',
      description: 'Show uncovered files',
      required: false,
      default: true,
    },
    format: {
      type: 'string',
      description: 'Output format (text, json, html)',
      required: false,
      default: 'text',
    },
  },
  async execute(params) {
    const { threshold, showUncovered, format } = params;
    
    // Run tests with coverage
    let command = 'npx jest --coverage --coverageReporters=json-summary';
    
    try {
      execSync(command, { stdio: 'ignore' });
    } catch {
      try {
        command = 'npx vitest run --coverage';
        execSync(command, { stdio: 'ignore' });
      } catch {
        return { error: 'Failed to run coverage. Ensure test runner is configured.' };
      }
    }
    
    // Read coverage report
    try {
      const coveragePath = 'coverage/coverage-summary.json';
      const coverageData = JSON.parse(readFileSync(coveragePath, 'utf-8'));
      
      const total = coverageData.total;
      const lines = total.lines.pct;
      const functions = total.functions.pct;
      const branches = total.branches.pct;
      const statements = total.statements.pct;
      
      const passed = lines >= threshold && functions >= threshold && 
                     branches >= threshold && statements >= threshold;
      
      const result: Record<string, unknown> = {
        passed,
        threshold,
        coverage: {
          lines,
          functions,
          branches,
          statements,
        },
      };
      
      if (showUncovered) {
        const uncovered: string[] = [];
        for (const [file, data] of Object.entries(coverageData)) {
          if (file === 'total') continue;
          const fileData = data as { lines: { pct: number } };
          if (fileData.lines.pct < threshold) {
            uncovered.push(file);
          }
        }
        result.uncovered = uncovered;
      }
      
      return result;
    } catch {
      return { error: 'Failed to read coverage report.' };
    }
  },
});
