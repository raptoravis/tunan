import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ECC_HOOK_PROFILE = process.env.ECC_HOOK_PROFILE || "standard";
const ECC_DISABLED_HOOKS = process.env.ECC_DISABLED_HOOKS?.split(",") || [];
function isHookDisabled(hookId) {
    return ECC_DISABLED_HOOKS.includes(hookId);
}
function shouldRunInProfile(level) {
    const profileOrder = { minimal: 0, standard: 1, strict: 2 };
    return profileOrder[ECC_HOOK_PROFILE] >= profileOrder[level];
}
// Resolve tunan root and skills directory
const repoRoot = path.resolve(__dirname, "../..");
const tunanSkillsDir = path.resolve(repoRoot, "plugins/skills");
/**
 * V2 Plugin: Export a named const that receives context and returns hooks.
 *
 * Context shape: { project, client, $, directory, worktree }
 * Each hook receives (input, output) and mutates output to affect behavior.
 */
export const TunanHooksPlugin = async (ctx) => {
    return {
        /**
         * Pre-execution safety checks for bash, write, and edit tools.
         */
        "tool.execute.before": async (input, _output) => {
            if (isHookDisabled("pre:tool:security"))
                return;
            if (input.tool === "bash" && shouldRunInProfile("strict")) {
                const cmd = input.args?.command || "";
                if (cmd.includes("git push") && !cmd.includes("--dry-run")) {
                    console.log("⚠️  Reminder: Review changes before pushing to remote.");
                }
            }
            if (input.tool === "write" || input.tool === "edit") {
                const content = input.args?.content || "";
                const secretPatterns = [
                    /api[_-]?key\s*[=:]\s*['"][^'"]+['"]/i,
                    /password\s*[=:]\s*['"][^'"]+['"]/i,
                    /token\s*[=:]\s*['"][^'"]+['"]/i,
                    /secret\s*[=:]\s*['"][^'"]+['"]/i,
                ];
                for (const pattern of secretPatterns) {
                    if (pattern.test(content)) {
                        console.log("⚠️  Warning: Potential hardcoded secret detected in file.");
                        break;
                    }
                }
            }
        },
        /**
         * Post-execution formatting and type-checking.
         */
        "tool.execute.after": async (input, _output) => {
            if (isHookDisabled("post:tool:format"))
                return;
            if ((input.tool === "write" || input.tool === "edit") &&
                shouldRunInProfile("strict")) {
                const filePath = input.args?.filePath || input.args?.file_path;
                if (filePath &&
                    (filePath.endsWith(".ts") ||
                        filePath.endsWith(".tsx") ||
                        filePath.endsWith(".js") ||
                        filePath.endsWith(".jsx"))) {
                    try {
                        const { execSync } = await import("child_process");
                        execSync(`npx prettier --write "${filePath}"`, { stdio: "ignore" });
                    }
                    catch {
                        // Prettier not available, skip
                    }
                }
            }
            if ((input.tool === "write" || input.tool === "edit") &&
                shouldRunInProfile("standard")) {
                const filePath = input.args?.filePath || input.args?.file_path;
                if (filePath && (filePath.endsWith(".ts") || filePath.endsWith(".tsx"))) {
                    try {
                        const { execSync } = await import("child_process");
                        execSync("npx tsc --noEmit", { stdio: "ignore" });
                    }
                    catch {
                        // TypeScript check failed, but don't block
                    }
                }
            }
        },
        /**
         * Session created: log available skills count.
         */
        "session.created": async (_input, _output) => {
            if (isHookDisabled("session:context"))
                return;
            const skills = fs.existsSync(tunanSkillsDir)
                ? fs
                    .readdirSync(tunanSkillsDir, { withFileTypes: true })
                    .filter((d) => d.isDirectory())
                    .map((d) => d.name)
                : [];
            console.log(`🔧 Tunan session started. ${skills.length} skills loaded. Use /tunan:<name> (e.g. /tunan:brainstorm, /tunan:plan).`);
        },
        /**
         * Shell environment: inject tunan session marker env vars.
         */
        "shell.env": async (_input, output) => {
            output.env = output.env || {};
            output.env.TUNAN_SESSION = "true";
            output.env.TUNAN_HOOK_PROFILE = ECC_HOOK_PROFILE;
        },
        /**
         * Permission asked: auto-approve safe read-only tools and safe bash commands.
         */
        "permission.asked": async (input, output) => {
            if (isHookDisabled("permission:auto"))
                return;
            const autoApproveTools = [
                "read", "glob", "grep",
            ];
            if (autoApproveTools.includes(input.tool)) {
                output.approve = true;
                return;
            }
            if (input.tool === "bash") {
                const cmd = input.args?.command || "";
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
                        output.approve = true;
                        return;
                    }
                }
            }
        },
    };
};
export default TunanHooksPlugin;
