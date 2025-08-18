# Workflow Documentation Prompt

You are tasked with analyzing transcripts and application files to create comprehensive workflow documentation. Your goal is to identify, extract, and document all current and expected workflows in a clear, structured markdown format.

## Input Materials
- Transcripts of user interviews, meetings, or discussions
- Application source code files
- Configuration files
- Documentation fragments
- User stories or requirements documents

## Analysis Instructions

### 1. Identify Workflows
- Look for process descriptions, user actions, and system behaviors
- Identify both explicit workflows (clearly documented) and implicit workflows (inferred from code/discussions)
- Note workflow triggers, steps, decision points, and outcomes
- Distinguish between current (as-is) and expected (to-be) workflows

### 2. Extract Key Information
For each workflow, capture:
- Workflow name and purpose
- Actors/roles involved
- Trigger events
- Sequential steps
- Decision points and branching logic
- Input/output data
- System interactions
- Error handling and edge cases
- Dependencies on other workflows

### 3. Categorize Workflows
Group workflows by:
- Business domain/functional area
- User type
- Frequency (daily, weekly, occasional)
- Priority/criticality
- Current vs. planned implementation

## Output Format

Create a markdown document with this structure:

```markdown
# Application Workflows Documentation

## Overview
[Brief description of the application and scope of workflows]

## Current Workflows

### [Workflow Category 1]

#### [Workflow Name]
**Status**: Current/Implemented
**Actors**: [List of roles/users]
**Trigger**: [What initiates this workflow]
**Frequency**: [How often this occurs]

**Steps**:
1. [Step description]
   - Input: [Required data/conditions]
   - Action: [What happens]
   - Output: [Result/next state]
2. [Continue for all steps...]

**Decision Points**:
- If [condition], then [action]
- If [condition], then [alternative action]

**Error Handling**:
- [Error scenario]: [How it's handled]

**Dependencies**:
- Requires: [Other workflows or systems]
- Triggers: [Other workflows this initiates]

---

### [Continue for all current workflows...]

## Expected/Planned Workflows

### [Workflow Category]

#### [Workflow Name]
**Status**: Planned/In Development
**Expected Implementation**: [Timeline if known]
**Actors**: [List of roles/users]
[Follow same structure as current workflows]

## Workflow Interactions

### Workflow Dependencies Map
[Describe how workflows connect and depend on each other]

### Data Flow Between Workflows
[Document how data moves between different workflows]

## Technical Implementation Notes

### Current Implementation
- [Technologies/frameworks used]
- [Key files/modules involved]
- [Integration points]

### Planned Changes
- [Upcoming technical changes]
- [Migration requirements]

## Appendices

### Glossary
[Define domain-specific terms]

### References
[List source documents, transcripts, and files analyzed]
