Analyze the provided file(s) and create two separate reports in markdown format, writing each to disk.

**Filename Convention:**
- Business Report: `{original-filename}-business-report-{YYYY-MM-DD}.md`
- Technical Report: `{original-filename}-technical-report-{YYYY-MM-DD}.md`

1. **Business Context Report**
   Describe the user-facing features and business purpose of this file. Focus on WHAT it does, not HOW it's coded. Include:
   - All user interactions and UI elements
   - Business workflows and processes supported
   - Data displayed and user decisions enabled
   - Integration with other business functions
   - User roles and permissions involved
   - Business value and outcomes

2. **Technical Implementation Report**
   Analyze the technical implementation of this file(s). Focus on HOW it's coded, not what it does for users.

   Provide technical implementation details only:
   - Code architecture and patterns used
   - Data structures and state management
   - API calls and data flow
   - Libraries and dependencies
   - Performance optimizations
   - Error handling approach
   - Component lifecycle and reactivity

Keep the reports completely separate - business report should contain no code details, technical report should contain no business context.
