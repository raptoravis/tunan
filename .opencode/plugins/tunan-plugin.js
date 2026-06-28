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
 * Resolve a path, expanding ~ and making absolute.
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

export const TunanPlugin = async ({ client, directory }) => {
  const homeDir = os.homedir();

  // Resolve plugin-relative paths
  const pluginDir = __dirname;
  const repoRoot = path.resolve(pluginDir, '../..');
  const tunanSkillsDir = path.resolve(repoRoot, 'plugins/skills');
  const instructionsFile = path.resolve(repoRoot, '.opencode/instructions/INSTRUCTIONS.md');

  const envConfigDir = normalizePath(process.env.OPENCODE_CONFIG_DIR, homeDir);

  const getBootstrapContent = () => {
    if (_bootstrapCache !== undefined) return _bootstrapCache;

    let instructionsBody = '';

    // Load INSTRUCTIONS.md for the guidance content
    if (fs.existsSync(instructionsFile)) {
      const fullContent = fs.readFileSync(instructionsFile, 'utf8');
      // Strip frontmatter if present
      const match = fullContent.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
      instructionsBody = match ? match[1].trim() : fullContent.trim();
    }

    const toolMapping = `**Tool mapping for OpenCode:**
When tunan skills request actions, use these OpenCode equivalents:
- Read files → \`read\`
- Create, edit, or delete files → \`apply_patch\`
- Run shell commands → \`bash\`
- Search file contents / find files → \`grep\`, \`glob\`
- Fetch a URL → \`webfetch\`
- Invoke another skill → native \`skill\` tool
- Dispatch a subagent → \`task\` with \`subagent_type: "general"\`
- Create or update tasks → \`todowrite\`

Use OpenCode's native \`skill\` tool to list and load any tunan skill.`;

    _bootstrapCache = `<EXTREMELY_IMPORTANT>
tunan is loaded and active — you have access to the full tunan skill library.

Use the \`skill\` tool to list available skills, or type \`/tunan:<name>\` to invoke one directly
(e.g. \`/tunan:brainstorm\`, \`/tunan:plan\`, \`/tunan:code-review\`, \`/tunan:work\`).

${instructionsBody ? `## Guidelines\n\n${instructionsBody}\n\n` : ''}
${toolMapping}
</EXTREMELY_IMPORTANT>`;

    return _bootstrapCache;
  };

  return {
    // Register tunan skills path in live config so OpenCode discovers them
    // without requiring manual config edits or symlinks.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(tunanSkillsDir)) {
        config.skills.paths.push(tunanSkillsDir);
      }
    },

    // Inject tunan bootstrap context into the first user message each session.
    // Uses a user message (not system) to avoid token bloat and model
    // compatibility issues. The sentinel guard prevents double injection.
    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;

      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;

      // Guard: skip if bootstrap already injected (detect sentinel)
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'))) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    }
  };
};
