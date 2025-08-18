## Prompt Template

Create a comprehensive implementation plan document for [FEATURE/SYSTEM NAME] with the following specifications:

### Core Requirements
- **Feature Type**: [e.g., Authentication System, Payment Integration, Search Feature, etc.]
- **Technology Stack**: [List primary technologies, frameworks, and libraries]
- **Integration Points**: [Existing systems/services this will integrate with]
- **Development Timeline**: [Expected duration]
- **Team Size**: [Number of developers]

### Technical Approach
- **Architecture Pattern**: [e.g., Hook-based, Component-based, Service-oriented]
- **State Management**: [e.g., React Query, Redux, Zustand, Context API]
- **Key Dependencies**: [List critical dependencies and versions]
- **Design Principles**: [List 3-5 core principles guiding the implementation]

### Specific Requirements
1. **Functional Requirements**:
   - [List key features/capabilities]
   - [User-facing functionality]
   - [Admin/management features]

2. **Non-Functional Requirements**:
   - Performance targets: [e.g., response times, load handling]
   - Security requirements: [e.g., encryption, access control]
   - Scalability needs: [e.g., concurrent users, data volume]
   - Browser/device support: [minimum supported versions]

3. **Constraints**:
   - Budget/resource limitations
   - Existing code patterns to follow
   - Compliance requirements
   - Technical debt considerations

### Document Structure Requirements

The implementation plan should include:

1. **Overview Section**
   - Brief description of the solution
   - Key benefits and rationale
   - High-level architecture approach

2. **Architecture Section**
   - Visual diagram (using Mermaid)
   - Key architectural principles (numbered list)
   - Component/service relationships
   - Data flow description

3. **Implementation Phases**
   - Break down into logical phases (0.5 to 2 days each)
   - For each phase include:
     - Objectives (what will be accomplished)
     - Deliverables (specific outputs)
     - Dependencies (what must be complete first)
     - Effort level (Low/Medium/High)
   - Total time estimate summary

4. **Folder Structure**
   - Show complete file organization
   - Use tree structure format
   - Follow existing project conventions

5. **Key Architectural Decisions**
   - List 10-15 numbered decisions
   - Brief rationale for each
   - Trade-offs considered

6. **API/Hook Catalog** (if applicable)
   - Primary interfaces with TypeScript signatures
   - Usage examples for each
   - Return values and parameters documented

7. **Pros and Cons Analysis**
   - Balanced assessment (4-6 each)
   - Specific to the chosen approach
   - Compare to alternatives if relevant

8. **Security Considerations** (if applicable)
   - Security measures by category
   - Best practices specific to the feature
   - Common pitfalls to avoid

9. **Code Examples**
   - Type definitions
   - Core implementation examples
   - Integration examples
   - 3-5 usage patterns

10. **Testing Strategy**
    - Mock/stub examples
    - Unit test examples
    - Integration test approach

11. **Key Recommendations**
    - 5-6 actionable recommendations
    - Priority order
    - Focus on practical implementation

### Output Format Requirements

- Use Markdown formatting throughout
- Include code blocks with language specification
- Use consistent heading hierarchy (##, ###, ####)
- Include inline code formatting for technical terms
- Use bullet points for lists
- Use tables where data comparison is helpful
- Keep sections focused and scannable
- write the final document to a file in the `specs`

### Tone and Style

- Technical but accessible
- Practical and implementation-focused
- Avoid unnecessary jargon
- Include specific examples
- Balance detail with readability
- Use active voice
- Be decisive in recommendations
