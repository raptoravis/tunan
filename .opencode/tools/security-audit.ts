import { defineTool } from '@opencode-ai/plugin/tool';
import { execSync } from 'child_process';
import { readFileSync } from 'fs';
import { globSync } from 'glob';

export const securityAudit = defineTool({
  name: 'security-audit',
  description: 'Run security vulnerability scan',
  parameters: {
    type: {
      type: 'string',
      description: 'Audit type (dependencies, secrets, code)',
      required: false,
      default: 'all',
    },
    fix: {
      type: 'boolean',
      description: 'Attempt to auto-fix issues',
      required: false,
      default: false,
    },
    severity: {
      type: 'string',
      description: 'Minimum severity level (low, medium, high, critical)',
      required: false,
      default: 'medium',
    },
  },
  async execute(params) {
    const { type, fix, severity } = params;
    
    const results: Record<string, unknown> = {
      type,
      severity,
      findings: [],
    };
    
    // Dependency audit
    if (type === 'all' || type === 'dependencies') {
      try {
        const output = execSync('npm audit --json', { encoding: 'utf-8' });
        const auditData = JSON.parse(output);
        
        if (auditData.vulnerabilities) {
          for (const [name, vuln] of Object.entries(auditData.vulnerabilities)) {
            const vulnData = vuln as { severity: string; via: string[] };
            if (shouldIncludeSeverity(vulnData.severity, severity)) {
              results.findings.push({
                type: 'dependency',
                name,
                severity: vulnData.severity,
                description: vulnData.via.join(', '),
              });
            }
          }
        }
      } catch {
        // npm audit failed, continue
      }
    }
    
    // Secret scanning
    if (type === 'all' || type === 'secrets') {
      const secretPatterns = [
        { pattern: /api[_-]?key\s*[=:]\s*['"][^'"]+['"]/i, name: 'API Key' },
        { pattern: /password\s*[=:]\s*['"][^'"]+['"]/i, name: 'Password' },
        { pattern: /token\s*[=:]\s*['"][^'"]+['"]/i, name: 'Token' },
        { pattern: /secret\s*[=:]\s*['"][^'"]+['"]/i, name: 'Secret' },
        { pattern: /private[_-]?key\s*[=:]\s*['"][^'"]+['"]/i, name: 'Private Key' },
      ];
      
      const files = globSync('**/*.{ts,tsx,js,jsx,json,env}', {
        ignore: ['node_modules/**', 'coverage/**', 'dist/**'],
      });
      
      for (const file of files) {
        try {
          const content = readFileSync(file, 'utf-8');
          const lines = content.split('\n');
          
          for (let i = 0; i < lines.length; i++) {
            for (const { pattern, name } of secretPatterns) {
              if (pattern.test(lines[i])) {
                results.findings.push({
                  type: 'secret',
                  file,
                  line: i + 1,
                  name,
                  severity: 'high',
                  description: `Potential ${name} found`,
                });
              }
            }
          }
        } catch {
          // File not readable
        }
      }
    }
    
    // Code security
    if (type === 'all' || type === 'code') {
      const codePatterns = [
        { pattern: /eval\s*\(/i, name: 'eval()', severity: 'high' },
        { pattern: /innerHTML\s*=/i, name: 'innerHTML', severity: 'medium' },
        { pattern: /document\.write\s*\(/i, name: 'document.write()', severity: 'medium' },
        { pattern: /exec\s*\(/i, name: 'exec()', severity: 'high' },
      ];
      
      const files = globSync('**/*.{ts,tsx,js,jsx}', {
        ignore: ['node_modules/**', 'coverage/**', 'dist/**'],
      });
      
      for (const file of files) {
        try {
          const content = readFileSync(file, 'utf-8');
          const lines = content.split('\n');
          
          for (let i = 0; i < lines.length; i++) {
            for (const { pattern, name, severity: sev } of codePatterns) {
              if (pattern.test(lines[i]) && shouldIncludeSeverity(sev, severity)) {
                results.findings.push({
                  type: 'code',
                  file,
                  line: i + 1,
                  name,
                  severity: sev,
                  description: `Potentially insecure usage of ${name}`,
                });
              }
            }
          }
        } catch {
          // File not readable
        }
      }
    }
    
    // Fix if requested
    if (fix) {
      try {
        execSync('npm audit fix', { stdio: 'ignore' });
        results.fixed = true;
      } catch {
        results.fixed = false;
      }
    }
    
    results.summary = {
      total: results.findings.length,
      critical: results.findings.filter((f: { severity: string }) => f.severity === 'critical').length,
      high: results.findings.filter((f: { severity: string }) => f.severity === 'high').length,
      medium: results.findings.filter((f: { severity: string }) => f.severity === 'medium').length,
      low: results.findings.filter((f: { severity: string }) => f.severity === 'low').length,
    };
    
    return results;
  },
});

function shouldIncludeSeverity(actual: string, minimum: string): boolean {
  const order = ['low', 'medium', 'high', 'critical'];
  return order.indexOf(actual) >= order.indexOf(minimum);
}
