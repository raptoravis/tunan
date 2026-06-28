/**
 * tunan plugin for OpenCode.ai
 *
 * Registers skills paths and injects bootstrap context so tunan skills
 * are auto-discovered without manual config or symlinks.
 *
 * Reference: Superpowers' superpowers.js pattern
 *   (https://github.com/obra/superpowers)
 */

import path from 'path';
import fs from 'fs';
import os from 'os';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Normalize a path: trim whitespace, expand ~, resolve to absolute.
 */
const normalizePath = (p, homeDir) => {
  if (!p || typeof p !== 'string') return null;
  let normalized = p.trim();
  if (!normalized) return null;
  if (normalized.startsWith('~/')) {
    normalized = path.join(homeDir, normalized.slice(2));
  } else if (normalized === '~') {
    normalized = homeDir;
  }
  return path.resolve(normalized);
};

// Module-level cache for bootstrap content (avoids redundant IO on every step)
let _bootstrapCache = undefined;

const createPlugin = async ({ client, directory }) => {
  const homeDir = os.homedir();

  // Resolve plugin-relative paths
  const pluginDir = __dirname;
  const repoRoot = path.resolve(pluginDir, '../..');
  const tunanSkillsDir = path.resolve(repoRoot, 'plugins/skills');
  const instructionsFile = path.resolve(repoRoot, '.opencode/instructions/INSTRUCTIONS.md');

  // Helper to generate bootstrap content (cached after first call)
  const getBootstrapContent = () => {
    if (_bootstrapCache !== undefined) return _bootstrapCache;

    let instructionsBody = '';

    if (fs.existsSync(instructionsFile)) {
      try {
        const fullContent = fs.readFileSync(instructionsFile, 'utf8');
        // Strip frontmatter if present
        const match = fullContent.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
        instructionsBody = match ? match[1].trim() : fullContent.trim();
      } catch (e) {
        console.error('[tunan] failed to read instructions file:', e.message);
      }
    }

    const toolMapping = [
      '**Tool mapping for OpenCode:**',
      'When tunan skills request actions, use these OpenCode equivalents:',
      '- Read files → `read`',
      '- Create, edit, or delete files → `apply_patch`',
      '- Run shell commands → `bash`',
      '- Search file contents / find files → `grep`, `glob`',
      '- Fetch a URL → `webfetch`',
      '- Invoke another skill → native `skill` tool',
      '- Dispatch a subagent → `task` with `subagent_type: "general"`',
      '- Create or update tasks → `todowrite`',
      '',
      "Use OpenCode's native `skill` tool to list and load any tunan skill.",
    ].join('\n');

    const parts = [
      '<EXTREMELY_IMPORTANT>',
      'tunan is loaded and active — you have access to the full tunan skill library.',
      '',
      'Use the `skill` tool to list available skills, or type `/tunan:<name>` to invoke one directly',
      '(e.g. `/tunan:brainstorm`, `/tunan:plan`, `/tunan:code-review`, `/tunan:work`).',
      '',
    ];

    if (instructionsBody) {
      parts.push('## Guidelines', '', instructionsBody, '');
    }

    parts.push(toolMapping, '</EXTREMELY_IMPORTANT>');
    _bootstrapCache = parts.join('\n');
    return _bootstrapCache;
  };

  return {
    // Register tunan skills path in live config so OpenCode discovers them
    // without requiring manual config edits or symlinks.
    config: async (config) => {
      try {
        config.skills = config.skills || {};
        config.skills.paths = config.skills.paths || [];
        if (!config.skills.paths.includes(tunanSkillsDir)) {
          config.skills.paths.push(tunanSkillsDir);
        }
      } catch (e) {
        console.error('[tunan] config hook error:', e.message);
      }
    },

    // Inject tunan bootstrap context into the first user message each session.
    // Uses a user message (not system) to avoid token bloat and model
    // compatibility issues. The sentinel guard prevents double injection.
    'experimental.chat.messages.transform': async (_input, output) => {
      try {
        const bootstrap = getBootstrapContent();
        if (!bootstrap) return;

        const messages = output?.messages;
        if (!messages || !Array.isArray(messages) || messages.length === 0) return;

        // Find first user message (handle both m.info.role and m.role for compatibility)
        const firstUser = messages.find(m => {
          if (!m) return false;
          const role = m.info?.role || m.role;
          return role === 'user';
        });
        if (!firstUser || !firstUser.parts || !Array.isArray(firstUser.parts) || firstUser.parts.length === 0) return;

        // Guard: skip if bootstrap already injected (detect sentinel)
        if (firstUser.parts.some(p => p?.type === 'text' && typeof p.text === 'string' && p.text.includes('EXTREMELY_IMPORTANT'))) return;

        // Prepend bootstrap as a clean text part (don't spread ref — avoid
        // carrying over fields from other part types like FilePart or ToolPart)
        firstUser.parts.unshift({ type: 'text', text: bootstrap });
      } catch (e) {
        console.error('[tunan] messages.transform error:', e.message, e.stack);
      }
    },
  };
};

// Export for various plugin resolution strategies OpenCode may use:
// - Named export (TunanPlugin) — direct Plugin function call
// - Default export — ES module default
// - server property — PluginModule format
const TunanPlugin = createPlugin;
export { TunanPlugin };
export default createPlugin;
export { createPlugin as server };
