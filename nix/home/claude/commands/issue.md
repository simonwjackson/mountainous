<task>
Fix a GitHub issue by analyzing the problem and implementing a solution.
</task>

<context>
You are tasked with resolving a GitHub issue. This requires understanding the problem, implementing changes, testing the solution, and submitting a proper pull request.
</context>

<input>
Issue ID or URL: {{ISSUE_ID}}
Repository: {{REPO_NAME}}
</input>

<steps>
1. Analyze the issue:
   - Run `gh issue view {{ISSUE_ID}}`
   - Identify the core problem
   - Note reproduction steps and error messages

2. Explore the codebase:
   - Search for relevant files
   - Understand the affected components
   - Command: `grep -r "relevant terms" --include="*.{file_extensions}" .`

3. Implement the fix:
   - Make necessary code changes
   - Follow project code style
   - Add inline documentation where needed

4. Test the solution:
   - Write appropriate tests
   - Run test suite: `npm test` (or equivalent)
   - Verify the issue is resolved

5. Quality checks:
   - Run linting: `npm run lint`
   - Run type checking: `npm run type-check`
   - Ensure all project-specific checks pass

6. Submit changes:
   - Create descriptive commit message
   - Push: `git push origin fix/issue-{{ISSUE_ID}}`
   - Create PR: `gh pr create --title "Fix: {{BRIEF_DESCRIPTION}}" --body "Resolves #{{ISSUE_ID}}"`
</steps>

<output>
- Working code fix
- Comprehensive tests
- Clean pull request
- Clear documentation
</output>

<constraints>
- Use GitHub CLI (`gh`) or MCP for all GitHub operations
- Follow project coding standards
- Maintain backward compatibility unless noted otherwise
</constraints>

The specific issue to fix is: {{ISSUE_DESCRIPTION}}
