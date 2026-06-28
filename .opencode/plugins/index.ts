import { TunanHooksPlugin } from './tunan-hooks.js';

// OpenCode expects plugin modules to export a factory function
const createPlugin = async () => TunanHooksPlugin;
export default createPlugin;
export { createPlugin as server };
