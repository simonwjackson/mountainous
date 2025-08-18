**COMMAND OVERVIEW**
Generate multiple proof-of-concept React component redesigns by analyzing existing component(s), extracting their business logic and domain understanding, then reimagining solutions with different UX patterns, architectural approaches, and visual treatments.

**Variables:**
count: 10
- `count` - Number of redesign POCs (1-N or "infinite")

**PHASE 1: COMPONENT ARCHAEOLOGY**
Deeply analyze the provided component(s) to understand:

**Business Logic Extraction**:
- What problem is this component solving?
- What are the core user needs it addresses?
- What business rules are embedded in the code?
- What data transformations occur?
- What are the success/failure states?

**Technical Analysis**:
- Component hierarchy and relationships
- State management patterns
- Data flow and dependencies
- API integrations
- Performance bottlenecks
- Accessibility implementation

**UX Pattern Recognition**:
- Current interaction paradigms
- Information architecture
- Visual hierarchy decisions
- User feedback mechanisms
- Error handling approaches

**PHASE 2: REVERSE ENGINEERING THE INTENT**
```javascript
// Example analysis output
const componentAnalysis = {
  corePurpose: "Extracted from component behavior",
  userGoals: [
    "Primary goal discovered from main interactions",
    "Secondary goals from supporting features"
  ],
  businessRules: [
    "Validation logic found in component",
    "Calculations and transformations",
    "Conditional rendering rules"
  ],
  dataModel: {
    inputs: "Props and user inputs",
    outputs: "Rendered UI and side effects",
    transformations: "How data is processed"
  },
  painPoints: [
    "Complex nested conditionals",
    "Unclear user flow",
    "Performance issues with large datasets"
  ]
};
```

**PHASE 3: REDESIGN ARCHITECTURE**
```
src/
├── original/
│   └── [OriginalComponent].jsx     # Reference implementation
├── analysis/
│   ├── BusinessLogic.md            # Extracted rules and requirements
│   ├── UserJourney.md              # Current vs improved flows
│   └── DesignSystem.md             # Visual language analysis
├── redesigns/
│   ├── POC01_SimplifiedFlow/
│   ├── POC02_AlternativeLayout/
│   ├── POC03_EnhancedInteraction/
│   └── POC[N]_[ApproachName]/
├── shared/
│   ├── businessLogic/              # Extracted, reusable logic
│   ├── hooks/                      # Custom hooks from analysis
│   └── utils/                      # Domain-specific utilities
└── comparison/
    └── SideBySide.jsx              # Compare original vs redesigns
```

## PHASE 4: REDESIGN PROGRESSION STRATEGY

### Comprehension Phase (POC01-03)
**POC01: Simplified Clarity**
- Strip away all non-essential elements
- Focus on core user goal
- Minimal viable interface
- Clear information hierarchy

**POC02: Enhanced Defaults**
- Smart defaults based on common use cases
- Progressive disclosure of complexity
- Contextual help and guidance
- Reduced cognitive load

**POC03: Workflow Optimization**
- Streamline multi-step processes
- Reduce clicks/interactions needed
- Anticipate user needs
- Inline validation and feedback

### Exploration Phase (POC04-07)
**POC04: Alternative Mental Models**
```jsx
// If original uses forms, try a conversational UI
// If original uses tables, try cards or visualizations
// If original uses wizards, try single-page apps
const AlternativeParadigm = () => {
  // Completely different approach to same problem
};
```

**POC05: Visual-First Approach**
- Replace text-heavy interfaces with visual representations
- Use charts/graphs where original used tables
- Implement drag-and-drop where original used forms
- Add meaningful animations for state changes

**POC06: Mobile-First Redesign**
- Touch-optimized interactions
- Gesture-based controls
- Responsive layouts
- Offline-first architecture

**POC07: Accessibility-First Design**
- Keyboard navigation optimization
- Screen reader enhancements
- High contrast modes
- Reduced motion options

### Innovation Phase (POC08-10)
**POC08: AI-Assisted Interface**
- Predictive inputs
- Smart suggestions
- Natural language processing
- Automated workflows

**POC09: Real-time Collaborative**
- Multi-user awareness
- Live updates
- Conflict resolution
- Activity streams

**POC10: Modular Composition**
- Micro-frontend approach
- Pluggable components
- User-customizable layouts
- Extension system

## PHASE 5: ANALYSIS PATTERNS

### Business Logic Extraction
```javascript
// Extract core business logic from component
const extractBusinessRules = (component) => {
  const rules = {
    validations: findValidationLogic(component),
    calculations: findCalculations(component),
    conditions: findConditionalLogic(component),
    transformations: findDataTransformations(component),
    sideEffects: findSideEffects(component)
  };

  return rules;
};

// Reimplement in cleaner, testable way
const useBusinessLogic = (data) => {
  const validate = useCallback((input) => {
    // Extracted validation logic
  }, []);

  const calculate = useCallback((values) => {
    // Extracted calculations
  }, []);

  return { validate, calculate };
};
```

### UX Pattern Analysis
```javascript
const analyzeUserFlow = (component) => {
  return {
    entryPoints: "How users start interacting",
    criticalPath: "Most important user journey",
    exitPoints: "How users complete tasks",
    painPoints: [
      "Where users might get stuck",
      "Confusing interactions",
      "Unnecessary complexity"
    ],
    opportunities: [
      "Where flow could be streamlined",
      "Where defaults could help",
      "Where automation could assist"
    ]
  };
};
```

## PHASE 6: REDESIGN TECHNIQUES

### Simplification Strategies
```jsx
// Original: Complex nested form
const OriginalForm = () => {
  return (
    <Form>
      <Section title="Basic Info">
        <Input name="field1" />
        <Input name="field2" />
        {showAdvanced && (
          <Subsection>
            {/* More fields */}
          </Subsection>
        )}
      </Section>
      {/* More sections */}
    </Form>
  );
};

// Redesign: Progressive disclosure
const SimplifiedForm = () => {
  const [step, setStep] = useState('essentials');

  return (
    <StepFlow>
      <EssentialFields />
      {needsMore && <OptionalFields />}
      <SmartDefaults />
    </StepFlow>
  );
};
```

### Information Architecture Redesign
```jsx
// Original: Everything visible
const OriginalDashboard = () => {
  return (
    <Grid>
      {allMetrics.map(metric => (
        <MetricCard {...metric} />
      ))}
    </Grid>
  );
};

// Redesign: Prioritized information
const RedesignedDashboard = () => {
  const priorities = usePrioritization(userRole, context);

  return (
    <Layout>
      <PrimaryMetrics data={priorities.critical} />
      <SecondaryMetrics data={priorities.important} collapsed />
      <Details data={priorities.optional} onDemand />
    </Layout>
  );
};
```

### Interaction Paradigm Shifts
```jsx
// Original: Traditional CRUD
const OriginalList = () => {
  return (
    <Table>
      <Actions>
        <Button onClick={create}>Create</Button>
        <Button onClick={edit}>Edit</Button>
        <Button onClick={delete}>Delete</Button>
      </Actions>
      <Rows data={items} />
    </Table>
  );
};

// Redesign: Inline everything
const RedesignedList = () => {
  return (
    <InteractiveList>
      {items.map(item => (
        <InlineEditable
          key={item.id}
          onSave={autoSave}
          onDelete={softDelete}
        >
          <SmartFields {...item} />
        </InlineEditable>
      ))}
      <InlineCreate onAdd={quickAdd} />
    </InteractiveList>
  );
};
```

## PHASE 7: COMPARISON FRAMEWORK

### Side-by-Side Analysis
```jsx
const ComparisonView = ({ original, redesign }) => {
  const metrics = useComparisonMetrics();

  return (
    <SplitView>
      <OriginalSide>
        <MetricsOverlay>
          Clicks needed: {metrics.original.clicks}
          Time to complete: {metrics.original.time}
          Error rate: {metrics.original.errors}
        </MetricsOverlay>
        {original}
      </OriginalSide>

      <RedesignSide>
        <MetricsOverlay>
          Clicks needed: {metrics.redesign.clicks}
          Time to complete: {metrics.redesign.time}
          Error rate: {metrics.redesign.errors}
        </MetricsOverlay>
        {redesign}
      </RedesignSide>

      <ImprovementSummary>
        {metrics.improvements.map(improvement => (
          <Metric
            name={improvement.name}
            change={improvement.percentage}
            impact={improvement.userImpact}
          />
        ))}
      </ImprovementSummary>
    </SplitView>
  );
};
```

### Success Metrics
```javascript
const measureRedesignSuccess = (original, redesign) => {
  return {
    complexity: {
      original: countDecisionPoints(original),
      redesign: countDecisionPoints(redesign),
      reduction: calculateReduction()
    },
    performance: {
      renderTime: measureRenderTime(redesign),
      interactionDelay: measureInteractionDelay(redesign),
      memoryUsage: measureMemoryUsage(redesign)
    },
    usability: {
      timeToComplete: simulateUserFlow(redesign),
      errorRate: calculateErrorPotential(redesign),
      learnability: assessLearnability(redesign)
    },
    maintainability: {
      linesOfCode: countLOC(redesign),
      cyclomaticComplexity: calculateComplexity(redesign),
      testCoverage: assessTestability(redesign)
    }
  };
};
```

## PHASE 8: EXECUTION STRATEGY

### Component Analysis Phase
1. **Parse and understand**:
   - Read through all component code
   - Trace data flow and dependencies
   - Identify core business logic
   - Extract design patterns

2. **Document findings**:
   - What works well?
   - What causes friction?
   - What could be simplified?
   - What's missing?

### Redesign Generation Phase
1. **Start with empathy**: Understand user frustrations
2. **Question everything**: Why was it built this way?
3. **Explore alternatives**: What if we tried...?
4. **Validate improvements**: Does this actually help?
5. **Preserve business logic**: Keep what works

### Pattern Evolution
- POC01-03: Fix obvious pain points
- POC04-06: Explore alternative approaches
- POC07-09: Push boundaries
- POC10+: Combine best ideas

---

**EXECUTION COMMAND**:
Analyze the provided component(s) to extract business logic, user flows, and design patterns. Begin generating redesign POCs that progressively reimagine the solution while preserving core functionality. Start with simplification and clarity improvements, then explore alternative interaction paradigms, and finally push into innovative territories. Each POC should be a complete, working reimplementation that solves the same business problem in a measurably better way.
