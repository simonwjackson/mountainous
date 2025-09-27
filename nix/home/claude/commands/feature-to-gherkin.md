# Feature to Gherkin Generator

<prompt>
  <title>Generate Gherkin Test Scenarios for Feature Directory</title>
  
  <objective>
    Analyze a feature directory and generate comprehensive Gherkin test scenarios based on the implementation.
  </objective>

  <instructions>
    <scanning_requirements>
      <feature_structure>
        Scan the feature directory at src/features/[feature-name]/:
        - api/*/: API endpoints with contracts, handlers, repositories, schemas
        - ui/components/: React components and their interactions
        - ui/routes/: TanStack Router route definitions
        - ui/hooks/: Custom React hooks
        - models/: TypeScript types and Zod schemas
        - utils/: Business logic utilities
        - e2e/: Existing E2E tests (avoid duplication)
      </feature_structure>

      <entity_analysis>
        Check for related entities in src/shared/entities/:
        - Identify entities that the feature depends on
        - Analyze their API contracts and data models
        - Understand entity relationships and dependencies
      </entity_analysis>

      <documentation_review>
        Look for documentation files:
        - USERGUIDE.md: User-facing documentation about feature usage
        - DOMAIN.md: Domain knowledge and business rules
        - README files: Feature architecture explanations
      </documentation_review>
    </scanning_requirements>

    <analysis_targets>
      <api_layer>
        - contract.ts: Available endpoints, request/response shapes
        - handler.ts: Business logic and error scenarios
        - repository.ts: Data access patterns
        - schema.ts: Validation rules and constraints
        - transform.ts: Data transformation logic
      </api_layer>

      <ui_layer>
        - *.tsx components: User interactions and UI states
        - hooks/*.ts: Custom hook logic and state management
        - routes/+*.tsx: Route handlers and data loading
      </ui_layer>

      <test_coverage>
        - *.test.ts: Unit test coverage
        - *.e2e.spec.ts: Existing E2E scenarios to avoid duplication
        - *.msw.handlers.ts: Mock scenarios that reveal edge cases
      </test_coverage>
    </analysis_targets>

    <scenario_coverage>
      <required_scenarios>
        - Happy paths: Primary user journeys and successful operations
        - Edge cases: Boundary conditions, empty states, maximum limits
        - Error handling: Validation failures, network errors, permission denials
        - Data integrity: CRUD operations, state consistency
        - User interactions: Form submissions, navigation, filtering, sorting
        - Integration points: API calls, entity relationships, cross-feature dependencies
        - Authorization: Role-based access, permission checks
        - Performance: Pagination, prefetching, caching behaviors
      </required_scenarios>
    </scenario_coverage>
  </instructions>

  <output_format>
    <gherkin_structure>
      Feature: [Feature Name]
        As a [user role]
        I want to [goal/desire]
        So that [benefit/value]

      Background:
        Given [common setup steps]

      Scenario: [Scenario name - descriptive and specific]
        Given [initial context]
        When [action taken]
        Then [expected outcome]
        And [additional assertions]

      Scenario Outline: [Data-driven scenario]
        Given [context with <variable>]
        When [action with <input>]
        Then [assertion with <expected>]
        
        Examples:
          | variable | input | expected |
          | value1   | data1 | result1  |
    </gherkin_structure>
  </output_format>

  <best_practices>
    <writing_guidelines>
      - Use business language, not technical implementation details
      - Each scenario should test one specific behavior
      - Scenarios should be independent and not rely on execution order
      - Use Background for common setup steps
      - Use Scenario Outlines for data-driven tests
      - Include both positive and negative test cases
    </writing_guidelines>

    <testing_considerations>
      - Consider accessibility scenarios (keyboard navigation, screen readers)
      - Test permission boundaries between different user roles
      - Cover state transitions and lifecycle events
      - Include performance-related scenarios where relevant
      - Test error recovery and resilience
    </testing_considerations>
  </best_practices>

  <example_usage>
    <input>
      Analyze src/features/annual-goals/ and generate comprehensive Gherkin test scenarios
    </input>
    
    <expected_output>
      Create feature files with well-structured Gherkin scenarios that:
      - Complement existing tests without duplication
      - Provide comprehensive coverage of the feature's functionality
      - Consider both the feature implementation and related entities
      - Follow Gherkin best practices and conventions
    </expected_output>
  </example_usage>

  <notes>
    <important>
      - Review existing E2E tests first to avoid duplication
      - Focus on user-visible behavior rather than implementation details
      - Consider the feature's interaction with shared entities
      - Generate scenarios that would catch regressions
    </important>
  </notes>
</prompt>