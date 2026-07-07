import type { Plugin } from "@opencode-ai/plugin";

/**
 * V2 Plugin API: exported as a named const that receives context and returns hooks.
 *
 * Context shape: { project, client, $, directory, worktree }
 * Each hook receives (input, output) and mutates output to affect behavior.
 */
declare const TunanHooksPlugin: Plugin;
export default TunanHooksPlugin;
export { TunanHooksPlugin };
//# sourceMappingURL=tunan-hooks.d.ts.map