// OpenCode loads plugins via the "plugin" config field. The module must export
// a factory function as default export or named "server" export.
// The factory: (input?: PluginInput, options?: PluginOptions) => Promise<Hooks>
export { default, default as server } from './tunan-hooks.js';
