import { defineTool } from '@opencode-ai/plugin/tool';
import { execSync } from 'child_process';
import { existsSync } from 'fs';

export const formatCode = defineTool({
  name: 'format-code',
  description: 'Format code using project formatter',
  parameters: {
    filePath: {
      type: 'string',
      description: 'File path to format (optional, formats all if not provided)',
      required: false,
    },
    formatter: {
      type: 'string',
      description: 'Formatter to use (prettier, eslint, biome)',
      required: false,
    },
  },
  async execute(params) {
    const { filePath, formatter } = params;
    
    // Detect formatter
    let detectedFormatter = formatter;
    
    if (!detectedFormatter) {
      if (existsSync('.prettierrc') || existsSync('prettier.config.js')) {
        detectedFormatter = 'prettier';
      } else if (existsSync('.eslintrc.js') || existsSync('eslint.config.js')) {
        detectedFormatter = 'eslint';
      } else if (existsSync('biome.json')) {
        detectedFormatter = 'biome';
      } else {
        detectedFormatter = 'prettier';
      }
    }
    
    // Build command
    let command = '';
    
    switch (detectedFormatter) {
      case 'prettier':
        command = filePath 
          ? `npx prettier --write "${filePath}"`
          : 'npx prettier --write .';
        break;
      case 'eslint':
        command = filePath
          ? `npx eslint --fix "${filePath}"`
          : 'npx eslint --fix .';
        break;
      case 'biome':
        command = filePath
          ? `npx biome format --write "${filePath}"`
          : 'npx biome format --write .';
        break;
      default:
        return { error: `Unknown formatter: ${detectedFormatter}` };
    }
    
    try {
      execSync(command, { stdio: 'pipe' });
      return { 
        success: true, 
        formatter: detectedFormatter,
        command,
        filePath: filePath || 'all files',
      };
    } catch (error) {
      return { 
        success: false, 
        error: error.message,
        formatter: detectedFormatter,
        command,
      };
    }
  },
});
