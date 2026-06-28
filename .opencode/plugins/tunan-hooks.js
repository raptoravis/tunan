import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { ChangedFilesStore } from './lib/changed-files-store.js';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ECC_HOOK_PROFILE = process.env.ECC_HOOK_PROFILE || 'standard';
const ECC_DISABLED_HOOKS = process.env.ECC_DISABLED_HOOKS?.split(',') || [];
function isHookDisabled(hookId) {
    return ECC_DISABLED_HOOKS.includes(hookId);
}
function shouldRunInProfile(level) {
    const profileOrder = { minimal: 0, standard: 1, strict: 2 };
    return profileOrder[ECC_HOOK_PROFILE] >= profileOrder[level];
}
const store = new ChangedFilesStore();
// Module-level cache for bootstrap content (avoids redundant IO on every step)
let _bootstrapCache = undefined;
// Resolve tunan root and skills directory
const repoRoot = path.resolve(__dirname, '../..');
const tunanSkillsDir = path.resolve(repoRoot, 'plugins/skills');
const instructionsFile = path.resolve(repoRoot, '.opencode/instructions/INSTRUCTIONS.md');
/**
 * Generate bootstrap content that tells the model about tunan skills and
 * tool mappings. Cached after first call to avoid redundant IO.
 */
function getBootstrapContent() {
    if (_bootstrapCache !== undefined)
        return _bootstrapCache;
    let instructionsBody = '';
    if (fs.existsSync(instructionsFile)) {
        try {
            const fullContent = fs.readFileSync(instructionsFile, 'utf8');
            // Strip frontmatter if present
            const match = fullContent.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
            instructionsBody = match ? match[1].trim() : fullContent.trim();
        }
        catch (e) {
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
 * The factory function. OpenCode's Plugin API expects a function
 * (input, options) => Promise<Hooks> that returns a flat Hooks object.
 * No { name, version, hooks } wrapper.
 */
const createTunanHooksPlugin = async () => ({
    /**
     * Register tunan skills path so OpenCode discovers slash commands.
     */
    config: async (config) => {
        try {
            // 1. Register skills path for skill tool/model access
            config.skills = config.skills || {};
            config.skills.paths = config.skills.paths || [];
            if (!config.skills.paths.includes(tunanSkillsDir)) {
                config.skills.paths.push(tunanSkillsDir);
            }
            // 2. Register each skill as a slash command so the UI discovers them
            config.command = config.command || {};
            if (fs.existsSync(tunanSkillsDir)) {
                const entries = fs.readdirSync(tunanSkillsDir, { withFileTypes: true });
                for (const entry of entries) {
                    if (!entry.isDirectory())
                        continue;
                    const skillDir = path.join(tunanSkillsDir, entry.name);
                    const skillFile = path.join(skillDir, 'SKILL.md');
                    if (!fs.existsSync(skillFile))
                        continue;
                    // Read frontmatter name and description
                    const content = fs.readFileSync(skillFile, 'utf8');
                    const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
                    let skillName = entry.name;
                    let skillDesc = '';
                    if (fmMatch) {
                        const fm = fmMatch[1];
                        const nameMatch = fm.match(/^name:\s*(.+)$/m);
                        if (nameMatch)
                            skillName = nameMatch[1].trim();
                        const descMatch = fm.match(/^description:\s*(.+)$/m);
                        if (descMatch) {
                            let d = descMatch[1].trim();
                            // Strip surrounding quotes
                            if ((d.startsWith("'") && d.endsWith("'")) || (d.startsWith('"') && d.endsWith('"'))) {
                                d = d.slice(1, -1);
                            }
                            skillDesc = d;
                        }
                    }
                    // Use namespaced name to avoid collision with other plugins/builtins
                    const cmdName = `tunan:${skillName}`;
                    if (!config.command[cmdName]) {
                        config.command[cmdName] = {
                            template: `# ${skillName}\n\n${skillDesc}\n\nUse the \`skill\` tool to load the tunan:${skillName} skill and follow its instructions.\n\n$ARGUMENTS`,
                            description: skillDesc.slice(0, 100),
                        };
                    }
                }
                console.error(`[tunan] registered ${Object.keys(config.command).filter(k => k.startsWith('tunan:')).length} slash commands`);
            }
        }
        catch (e) {
            console.error('[tunan] config hook error:', e.message);
        }
    },
    /**
     * Inject tunan bootstrap context into the first user message each session.
     */
    'experimental.chat.messages.transform': async (_input, output) => {
        try {
            const bootstrap = getBootstrapContent();
            if (!bootstrap)
                return;
            const messages = output?.messages;
            if (!messages || !Array.isArray(messages) || messages.length === 0)
                return;
            // Find first user message
            const firstUser = messages.find((m) => {
                if (!m)
                    return false;
                const role = m.info?.role || m.role;
                return role === 'user';
            });
            if (!firstUser || !firstUser.parts || !Array.isArray(firstUser.parts) || firstUser.parts.length === 0)
                return;
            // Guard: skip if bootstrap already injected (detect sentinel)
            if (firstUser.parts.some((p) => p?.type === 'text' && typeof p.text === 'string' && p.text.includes('EXTREMELY_IMPORTANT')))
                return;
            // Prepend bootstrap as a clean text part
            firstUser.parts.unshift({ type: 'text', text: bootstrap });
        }
        catch (e) {
            console.error('[tunan] messages.transform error:', e.message, e.stack);
        }
    },
    'tool.execute.before': async (ctx) => {
        if (isHookDisabled('pre:tool:security'))
            return;
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
        if (isHookDisabled('post:tool:format'))
            return;
        const { tool, input, output } = ctx;
        if ((tool === 'write' || tool === 'edit') && shouldRunInProfile('strict')) {
            const filePath = input.file_path || input.filePath;
            if (filePath && (filePath.endsWith('.ts') || filePath.endsWith('.tsx') || filePath.endsWith('.js') || filePath.endsWith('.jsx'))) {
                try {
                    const { execSync } = await import('child_process');
                    execSync(`npx prettier --write "${filePath}"`, { stdio: 'ignore' });
                }
                catch {
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
                }
                catch {
                    // TypeScript check failed, but don't block
                }
            }
        }
    },
    'session.created': async (_ctx) => {
        if (isHookDisabled('session:context'))
            return;
        store.clear();
        const skills = fs.readdirSync(tunanSkillsDir, { withFileTypes: true })
            .filter(d => d.isDirectory())
            .map(d => d.name);
        console.log(`🔧 Tunan session started. ${skills.length} skills loaded. Use /tunan:<name> (e.g. /tunan:brainstorm, /tunan:plan).`);
    },
    'session.idle': async (ctx) => {
        if (isHookDisabled('session:idle'))
            return;
        if (shouldRunInProfile('standard')) {
            const changes = store.getChanges();
            const jsFiles = changes.filter(f => f.path.endsWith('.js') || f.path.endsWith('.ts') || f.path.endsWith('.tsx'));
            for (const file of jsFiles) {
                try {
                    const { readFileSync } = await import('fs');
                    const content = readFileSync(file.path, 'utf-8');
                    if (content.includes('console.log(')) {
                        console.log(`⚠️  ${file.path} contains console.log statements.`);
                    }
                }
                catch {
                    // File not readable
                }
            }
        }
    },
    'file.edited': async (ctx) => {
        if (isHookDisabled('file:edited'))
            return;
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
        if (isHookDisabled('permission:auto'))
            return;
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
});
export default createTunanHooksPlugin;
export { createTunanHooksPlugin as server };
//# sourceMappingURL=tunan-hooks.js.map