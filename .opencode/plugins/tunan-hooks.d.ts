/**
 * The factory function. OpenCode's Plugin API expects a function
 * (input, options) => Promise<Hooks> that returns a flat Hooks object.
 * No { name, version, hooks } wrapper.
 */
declare const createTunanHooksPlugin: () => Promise<{
    /**
     * Register tunan skills path so OpenCode discovers slash commands.
     */
    config: (config: any) => Promise<void>;
    /**
     * Inject tunan bootstrap context into the first user message each session.
     */
    'experimental.chat.messages.transform': (_input: any, output: any) => Promise<void>;
    'tool.execute.before': (ctx: any) => Promise<void>;
    'tool.execute.after': (ctx: any) => Promise<void>;
    'session.created': (_ctx: any) => Promise<void>;
    'session.idle': (ctx: any) => Promise<void>;
    'file.edited': (ctx: any) => Promise<void>;
    'shell.env': (ctx: any) => Promise<{
        TUNAN_SESSION: string;
        TUNAN_HOOK_PROFILE: string;
    }>;
    'permission.ask': (ctx: any) => Promise<{
        approve: boolean;
    } | undefined>;
}>;
export default createTunanHooksPlugin;
export { createTunanHooksPlugin as server };
//# sourceMappingURL=tunan-hooks.d.ts.map