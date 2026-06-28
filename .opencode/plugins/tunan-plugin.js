/**
 * tunan plugin for OpenCode.ai — MAIN ENTRY (npm package)
 *
 * This is the entry point that `package.json` → `"main"` points to.
 * It gets bundled into the npm package and loaded by OpenCode when
 * the plugin is installed globally or per-project.
 *
 * Factory returns a flat Hooks object (no {name,version,hooks} wrapper).
 */
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Resolve paths from the package root (2 levels up from .opencode/plugins/)
const packageRoot = path.resolve(__dirname, '../..');
const tunanSkillsDir = path.resolve(packageRoot, 'plugins/skills');
const instructionsFile = path.resolve(packageRoot, 'plugins/.opencode/INSTRUCTIONS.md');

// Module-level cache for bootstrap content
let _bootstrapCache = undefined;

/**
 * Generate bootstrap content that tells the model about tunan skills.
 */
function getBootstrapContent() {
  if (_bootstrapCache !== undefined) return _bootstrapCache;

  let instructionsBody = '';
  if (fs.existsSync(instructionsFile)) {
    try {
      const fullContent = fs.readFileSync(instructionsFile, 'utf8');
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
}

/**
 * Scan skill directories and read name/description from SKILL.md frontmatter.
 */
function scanSkills() {
  const skills = [];
  if (!fs.existsSync(tunanSkillsDir)) return skills;

  const entries = fs.readdirSync(tunanSkillsDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const skillFile = path.join(tunanSkillsDir, entry.name, 'SKILL.md');
    if (!fs.existsSync(skillFile)) continue;

    const content = fs.readFileSync(skillFile, 'utf8');
    const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
    let skillName = entry.name;
    let skillDesc = '';
    if (fmMatch) {
      const fm = fmMatch[1];
      const nameMatch = fm.match(/^name:\s*(.+)$/m);
      if (nameMatch) skillName = nameMatch[1].trim();
      const descMatch = fm.match(/^description:\s*(.+)$/m);
      if (descMatch) {
        let d = descMatch[1].trim();
        if ((d.startsWith("'") && d.endsWith("'")) || (d.startsWith('"') && d.endsWith('"'))) {
          d = d.slice(1, -1);
        }
        skillDesc = d;
      }
    }
    skills.push({ name: skillName, description: skillDesc });
  }
  return skills;
}

/**
 * Factory function — the plugin entry.
 * OpenCode v1 Plugin API: (input, options) => Promise<Hooks>
 */
const createPlugin = async () => {
  const skills = scanSkills();

  return {
    config: async (config) => {
      try {
        config.skills = config.skills || {};
        config.skills.paths = config.skills.paths || [];
        if (!config.skills.paths.includes(tunanSkillsDir)) {
          config.skills.paths.push(tunanSkillsDir);
        }

        // Register each skill as a slash command (use tunan- prefix: colon
        // breaks slash-command prefix matching in the UI)
        config.command = config.command || {};
        for (const skill of skills) {
          const cmdName = `tunan-${skill.name}`;
          if (!config.command[cmdName]) {
            config.command[cmdName] = {
              template: `# ${skill.name}\n\n${skill.description}\n\nUse the \`skill\` tool to load the tunan:${skill.name} skill and follow its instructions.\n\n$ARGUMENTS`,
              description: skill.description.slice(0, 100),
            };
          }
        }
        console.error(`[tunan] registered ${skills.length} skills + ${Object.keys(config.command).filter(k => k.startsWith('tunan-')).length} slash commands`);
      } catch (e) {
        console.error('[tunan] config hook error:', e.message);
      }
    },

    'experimental.chat.messages.transform': async (_input, output) => {
      try {
        const bootstrap = getBootstrapContent();
        if (!bootstrap) return;

        const messages = output?.messages;
        if (!messages || !Array.isArray(messages) || messages.length === 0) return;

        const firstUser = messages.find(m => {
          if (!m) return false;
          const role = m.info?.role || m.role;
          return role === 'user';
        });
        if (!firstUser || !firstUser.parts || !Array.isArray(firstUser.parts) || firstUser.parts.length === 0) return;

        if (firstUser.parts.some(p => p?.type === 'text' && typeof p.text === 'string' && p.text.includes('EXTREMELY_IMPORTANT'))) return;

        firstUser.parts.unshift({ type: 'text', text: bootstrap });
      } catch (e) {
        console.error('[tunan] messages.transform error:', e.message, e.stack);
      }
    },

    'session.created': async () => {
      console.log(`🔧 Tunan session started. ${skills.length} skills loaded. Use /tunan:<name> (e.g. /tunan:brainstorm, /tunan:plan).`);
    },
  };
};

// OpenCode expects the module to export a factory function as default or "server"
export default createPlugin;
export { createPlugin as server };
