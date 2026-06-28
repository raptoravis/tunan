# tunan OpenCode Instructions

## Security Guidelines

### Hardcoded Secrets Detection
- Scan for API keys, passwords, tokens, and credentials in code
- Use environment variables for sensitive configuration
- Never commit secrets to version control

### Input Validation
- Validate all user inputs at system boundaries
- Use parameterized queries to prevent SQL injection
- Sanitize output to prevent XSS attacks

### Dependency Security
- Regularly audit dependencies for vulnerabilities
- Use lockfiles to ensure reproducible builds
- Keep dependencies updated to latest stable versions

## Coding Standards

### Immutability Principle
- Prefer immutable data structures
- Use const/let instead of var
- Avoid side effects where possible

### File Organization
- Keep files small and focused
- One class/module per file
- Clear separation of concerns

### Error Handling
- Use structured error handling
- Provide meaningful error messages
- Log errors appropriately

### Input Validation
- Validate at system boundaries
- Use type checking where available
- Fail fast on invalid input

## Testing Requirements

### Minimum Coverage
- 80% code coverage minimum
- 100% coverage for critical paths
- Test both happy and error paths

### TDD Workflow
1. Write failing test
2. Write minimal code to pass
3. Refactor while keeping tests green

### Test Types
- **Unit Tests**: Test individual functions/methods
- **Integration Tests**: Test component interactions
- **E2E Tests**: Test complete user flows

## Git Workflow

### Commit Messages
- Use conventional commits format
- Keep subject line under 72 characters
- Reference issues when applicable

### PR Workflow
- Create feature branches from main
- Keep PRs focused and small
- Require code review before merge

## Agent Usage

### Available Agents
- `build`: Primary coding agent
- `planner`: Implementation planning
- `architect`: System design
- `code-reviewer`: Code review
- `security-reviewer`: Security analysis
- `tdd-guide`: Test-driven development
- `build-error-resolver`: Build error fixes
- `e2e-runner`: E2E testing
- `doc-updater`: Documentation
- `refactor-cleaner`: Dead code cleanup
- `database-reviewer`: Database optimization
- `docs-lookup`: Documentation lookup
- `harness-optimizer`: Config tuning
- `loop-operator`: Autonomous loops

### When to Use
- Use `planner` before implementation
- Use `code-reviewer` after changes
- Use `security-reviewer` for sensitive code
- Use `tdd-guide` for new features
- Use `build-error-resolver` for build failures

## Performance Optimization

### Model Selection
- Use `haiku` for simple tasks
- Use `sonnet` for most development work
- Use `opus` for complex reasoning

### Context Window Management
- Keep under 10 MCPs enabled per project
- Keep under 80 tools active
- Use `/compact` at logical breakpoints

## OpenCode Specific

### Manual Operations
OpenCode does not support hooks, so these must be run manually:
- Code formatting (prettier)
- Type checking (tsc --noEmit)
- Linting (eslint)
- Testing (jest/vitest)

### Available Commands
- `/plan`: Create implementation plan
- `/tdd`: TDD workflow
- `/code-review`: Review code changes
- `/security`: Security review
- `/build-fix`: Fix build errors
- `/e2e`: E2E tests
- `/refactor-clean`: Remove dead code
- `/orchestrate`: Multi-agent workflow
- `/verify`: Verification loop
- `/update-docs`: Update docs
- `/test-coverage`: Coverage analysis
- `/brainstorm`: Explore requirements
- `/work`: Execute work items
- `/compound`: Document solved problems
- `/debug`: Find root causes
- `/optimize`: Run optimization loops
