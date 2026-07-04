#!/usr/bin/env node

import { execSync } from 'child_process';
import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

function usage() {
  console.log(`tunan installer — install skills for AI coding agents

Usage:
  npx tunan install [--claude] [--codex] [--opencode] [--reasonix] [--all] [--force]

Install to specific agents:
  npx tunan install --codex          Install for Codex
  npx tunan install --claude         Install for Claude Code
  npx tunan install --opencode       Install for OpenCode
  npx tunan install --reasonix       Install for Reasonix
  npx tunan install --all            Install for all agents
  npx tunan install --all --force    Force-replace existing skills

After installing, restart your agent and run /tunan:setup in any project.
`);
}

const args = process.argv.slice(2);

if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
  usage();
  process.exit(0);
}

const subCmd = args[0];

if (subCmd === 'install') {
  const rawArgs = args.slice(1);
  const isWindows = process.platform === 'win32';

  if (isWindows) {
    // Translate bash-style --flags to PowerShell -Flags
    const psArgs = rawArgs.map(a => {
      if (a === '--codex') return '-Codex';
      if (a === '--claude') return '-Claude';
      if (a === '--opencode') return '-OpenCode';
      if (a === '--reasonix') return '-Reasonix';
      if (a === '--agents') return '-Agents';
      if (a === '--all') return '-All';
      if (a === '--force') return '-Force';
      if (a === '--prune-managed') return '-PruneManaged';
      return a;
    });

    const ps1Path = path.join(rootDir, 'install.ps1');
    if (!fs.existsSync(ps1Path)) {
      console.error('install.ps1 not found. Run from the tunan repo root.');
      process.exit(1);
    }
    try {
      execSync(`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${ps1Path}" ${psArgs.join(' ')}`, { stdio: 'inherit' });
    } catch (e) {
      process.exit(e.status || 1);
    }
  } else {
    const shPath = path.join(rootDir, 'install.sh');
    if (!fs.existsSync(shPath)) {
      console.error('install.sh not found. Run from the tunan repo root.');
      process.exit(1);
    }
    try {
      execSync(`bash "${shPath}" ${rawArgs.join(' ')}`, { stdio: 'inherit' });
    } catch (e) {
      process.exit(e.status || 1);
    }
  }
} else {
  console.error(`Unknown command: ${subCmd}`);
  usage();
  process.exit(1);
}