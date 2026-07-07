/**
 * tunan plugin for OpenCode — MAIN ENTRY (npm package)
 *
 * V2 Plugin API: exports a named const that receives context and returns hooks.
 * This is the entry point that `package.json` → `"main"` points to.
 */

import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const packageRoot = path.resolve(__dirname, "../..");
const tunanSkillsDir = path.resolve(packageRoot, "plugins/skills");

/**
 * V2 Plugin entry point.
 * Context: { project, client, $, directory, worktree }
 */
export const TunanPlugin = async (ctx) => {
  const skills = fs.existsSync(tunanSkillsDir)
    ? fs
        .readdirSync(tunanSkillsDir, { withFileTypes: true })
        .filter((d) => d.isDirectory())
        .map((d) => d.name)
    : [];

  return {
    /**
     * Session created: log available skills count.
     */
    "session.created": async (_input, _output) => {
      console.log(
        `🔧 Tunan session started. ${skills.length} skills loaded. Use /tunan:<name> (e.g. /tunan:brainstorm, /tunan:plan).`
      );
    },

    /**
     * Shell environment: inject tunan session marker env vars.
     */
    "shell.env": async (_input, output) => {
      output.env = output.env || {};
      output.env.TUNAN_SESSION = "true";
    },
  };
};

export default TunanPlugin;
