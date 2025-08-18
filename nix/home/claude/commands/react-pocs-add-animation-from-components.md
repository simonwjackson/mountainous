**COMMAND OVERVIEW**
Generate multiple proof-of-concept enhancements for existing React components, progressively adding meaningful animations using Framer Motion and React Spring while preserving all business logic.

**Variables:**
count: 10
- `count` - Number of POC iterations (1-N or "infinite")

**PHASE 1: COMPONENT ANALYSIS**
Deeply analyze the provided component(s) to understand:
- **Business Logic**: Extract and preserve all functionality
- **Data Flow**: How state changes and propagates
- **User Interactions**: Click handlers, form inputs, gestures
- **Component Hierarchy**: Parent/child relationships
- **Current Styling**: CSS classes, inline styles, styled-components
- **Key User Actions**: What deserves animation emphasis
- **State Transitions**: What changes could be animated

**Component Preservation Rules**:
- NEVER modify business logic or data flow
- PRESERVE all existing functionality
- MAINTAIN component API (props, callbacks)
- EXTEND rather than replace
- ADD animation layers without breaking features

**PHASE 2: ANIMATION OPPORTUNITY MAPPING**
```javascript
// Analyze component for animation opportunities
const analysisMap = {
  mounts: [],      // Component entries/exits
  updates: [],     // State changes to animate
  interactions: [], // User actions to enhance
  lists: [],       // Collections that could stagger
  values: [],      // Numbers/metrics to transition
  layouts: [],     // Structural changes to animate
  feedbacks: [],   // Success/error states to emphasize
};
```

**PHASE 3: ENHANCEMENT ARCHITECTURE**
```
Original Structure:              Enhanced Structure:
ComponentName.jsx        →       ComponentName.jsx (preserved)
                                AnimatedComponentName.jsx (wrapper)
                                useComponentAnimations.js (hooks)
                                componentAnimations.js (configs)
```

## PHASE 4: POC PROGRESSION STRATEGY

### Analysis POCs (POC01-02)

**POC01: Component Deep Dive**
```jsx
// Document existing component behavior
const ComponentAnalysis = () => {
  // 1. List all state variables
  // 2. Map all user interactions
  // 3. Identify render triggers
  // 4. Document data dependencies
  // 5. Note visual hierarchies

  return (
    <AnalysisReport>
      <StateMap />
      <InteractionMap />
      <AnimationOpportunities />
    </AnalysisReport>
  );
};
```

**POC02: Minimal Animation Layer**
```jsx
// Wrap existing component with basic animations
import OriginalComponent from './OriginalComponent';

const AnimatedComponent = (props) => {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      <OriginalComponent {...props} />
    </motion.div>
  );
};
```

### Framer Motion Enhancements (POC03-05)

**POC03: Mount/Unmount Animations**
```jsx
// Enhance component visibility transitions
const EnhancedComponent = (props) => {
  // Detect mount points from original
  const mountPoints = detectMountPoints(OriginalComponent);

  return (
    <AnimatePresence mode="wait">
      {mountPoints.map(mount => (
        <motion.div
          key={mount.key}
          initial={mount.hidden}
          animate={mount.visible}
          exit={mount.exit}
        >
          <OriginalComponent {...props} />
        </motion.div>
      ))}
    </AnimatePresence>
  );
};
```

**POC04: State Change Animations**
```jsx
// Animate internal state changes
const StateAnimatedComponent = (props) => {
  // Hook into component state changes
  const stateProxy = useStateProxy(OriginalComponent);

  return (
    <motion.div
      animate={getAnimationFromState(stateProxy.current)}
      transition={{ type: "spring", stiffness: 300 }}
    >
      <OriginalComponent
        {...props}
        {...stateProxy.overrides}
      />
    </motion.div>
  );
};
```

**POC05: Interactive Enhancements**
```jsx
// Add gesture and hover animations
const InteractiveComponent = (props) => {
  const [isHovered, setIsHovered] = useState(false);
  const interactions = extractInteractions(OriginalComponent);

  return (
    <motion.div
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      onHoverStart={() => setIsHovered(true)}
      onHoverEnd={() => setIsHovered(false)}
    >
      <OriginalComponent
        {...props}
        {...enhanceCallbacks(props, interactions)}
      />
      <AnimatedHighlights show={isHovered} />
    </motion.div>
  );
};
```

### React Spring Enhancements (POC06-08)

**POC06: Value Transitions**
```jsx
// Smooth numeric value changes
const ValueAnimatedComponent = (props) => {
  // Detect numeric props and state
  const numericValues = extractNumericValues(props, OriginalComponent);

  const springs = useSprings(
    numericValues.length,
    numericValues.map(val => ({
      from: { value: val.previous },
      to: { value: val.current },
      config: config.gentle
    }))
  );

  return (
    <OriginalComponent
      {...props}
      {...mapAnimatedValues(props, springs)}
    />
  );
};
```

**POC07: List Animations**
```jsx
// Enhance lists and collections
const ListAnimatedComponent = (props) => {
  const lists = detectListProps(props, OriginalComponent);

  const trails = useTrail(lists.primary.length, {
    from: { opacity: 0, x: -20 },
    to: { opacity: 1, x: 0 },
    config: config.gentle
  });

  // Inject animated items back into original
  const enhancedProps = {
    ...props,
    [lists.primary.propName]: trails.map((style, i) => (
      <animated.div style={style}>
        {lists.primary.items[i]}
      </animated.div>
    ))
  };

  return <OriginalComponent {...enhancedProps} />;
};
```

**POC08: Gesture Controls**
```jsx
// Add drag and swipe gestures
const GestureEnhancedComponent = (props) => {
  const [{ x, y }, api] = useSpring(() => ({ x: 0, y: 0 }));
  const bind = useDrag(({ offset: [x, y] }) => {
    api.start({ x, y });
  });

  return (
    <animated.div {...bind()} style={{ x, y }}>
      <OriginalComponent {...props} />
    </animated.div>
  );
};
```

### Advanced Hybrids (POC09-10)

**POC09: Intelligent Animation Wrapper**
```jsx
// Auto-detect and apply appropriate animations
const IntelligentAnimationWrapper = (props) => {
  const analysis = useComponentAnalysis(OriginalComponent);
  const motionConfig = generateMotionConfig(analysis);
  const springConfig = generateSpringConfig(analysis);

  return (
    <HybridAnimationProvider
      motion={motionConfig}
      spring={springConfig}
    >
      <AutoAnimatedComponent
        component={OriginalComponent}
        props={props}
        analysis={analysis}
      />
    </HybridAnimationProvider>
  );
};
```

**POC10: Performance-Optimized Enhancement**
```jsx
// Full enhancement with performance monitoring
const OptimizedEnhancement = (props) => {
  const perfMonitor = usePerformanceMonitor();
  const animationLevel = useAdaptiveComplexity(perfMonitor);

  return (
    <AnimationBoundary level={animationLevel}>
      <EnhancedComponent
        {...props}
        animationLevel={animationLevel}
        originalComponent={OriginalComponent}
      />
    </AnimationBoundary>
  );
};
```

## PHASE 5: ENHANCEMENT PATTERNS

### Pattern 1: Non-Invasive Wrapper
```jsx
// Preserve original completely
export const withAnimation = (Component) => {
  return (props) => {
    const [ref, inView] = useInView();

    return (
      <motion.div
        ref={ref}
        initial={{ opacity: 0, y: 20 }}
        animate={inView ? { opacity: 1, y: 0 } : {}}
      >
        <Component {...props} />
      </motion.div>
    );
  };
};

// Usage
const AnimatedOriginal = withAnimation(OriginalComponent);
```

### Pattern 2: Prop Injection
```jsx
// Enhance props before passing
const enhanceProps = (props, animationState) => {
  return {
    ...props,
    // Intercept callbacks
    onClick: (e) => {
      triggerClickAnimation();
      props.onClick?.(e);
    },
    // Enhance children
    children: React.Children.map(props.children, child =>
      React.cloneElement(child, { animated: true })
    )
  };
};
```

### Pattern 3: State Proxy
```jsx
// Monitor state without modifying logic
const useStateProxy = (Component) => {
  const [proxyState, setProxyState] = useState({});

  // Intercept setState calls
  const enhancedSetState = (updates) => {
    animateStateChange(updates);
    setProxyState(updates);
  };

  return { proxyState, enhancedSetState };
};
```

## PHASE 6: ANALYSIS UTILITIES

### Component Scanner
```javascript
const analyzeComponent = (Component) => {
  const analysis = {
    props: extractPropTypes(Component),
    state: detectStateUsage(Component),
    hooks: findHookUsage(Component),
    events: extractEventHandlers(Component),
    renders: analyzeRenderMethod(Component),
    children: detectChildComponents(Component)
  };

  return {
    ...analysis,
    animationOpportunities: suggestAnimations(analysis)
  };
};
```

### Animation Suggester
```javascript
const suggestAnimations = (analysis) => {
  const suggestions = [];

  // Suggest based on patterns
  if (analysis.renders.conditional) {
    suggestions.push({
      type: 'mount',
      technique: 'framer',
      config: 'fadeScale'
    });
  }

  if (analysis.state.numeric) {
    suggestions.push({
      type: 'value',
      technique: 'spring',
      config: 'gentle'
    });
  }

  if (analysis.props.list) {
    suggestions.push({
      type: 'stagger',
      technique: 'either',
      config: 'trail'
    });
  }

  return suggestions;
};
```

## PHASE 7: TESTING & VALIDATION

### Functionality Preservation Tests
```javascript
const testEnhancement = (Original, Enhanced) => {
  // Ensure same output
  expect(render(Enhanced)).toEqual(render(Original));

  // Ensure callbacks work
  const mockCallback = jest.fn();
  fireEvent.click(getByRole('button'));
  expect(mockCallback).toHaveBeenCalled();

  // Ensure state updates work
  act(() => {
    updateState(newValue);
  });
  expect(getByText(newValue)).toBeInTheDocument();
};
```

### Performance Monitoring
```javascript
const usePerformanceMonitor = () => {
  const [metrics, setMetrics] = useState({
    fps: 60,
    renderTime: 0,
    animationCost: 0
  });

  useEffect(() => {
    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      // Calculate performance impact
    });

    observer.observe({ entryTypes: ['measure'] });
  }, []);

  return metrics;
};
```

## PHASE 8: DOCUMENTATION TEMPLATE

```markdown
# Animation Enhancement for [ComponentName]

## Original Component Analysis
- Purpose: [What it does]
- State: [State variables]
- Props: [Expected props]
- Interactions: [User actions]

## Animation Additions
- Mount/Unmount: [Description]
- State Changes: [What animates]
- Interactions: [Enhanced behaviors]
- Performance: [Impact assessment]

## Usage
\`\`\`jsx
import { AnimatedComponentName } from './enhancements';

// Drop-in replacement
<AnimatedComponentName {...originalProps} />
\`\`\`

## Configuration
\`\`\`jsx
// Customize animation intensity
<AnimatedComponentName
  animationLevel="subtle|medium|dramatic"
  disableAnimations={false}
/>
\`\`\`
```

---

**EXECUTION COMMAND**:
Analyze the provided component(s) to understand their structure and behavior, then create progressive animation enhancements starting with simple wrappers (POC01-02), advancing through Framer Motion enhancements (POC03-05), React Spring additions (POC06-08), and culminating in intelligent hybrid systems (POC09-10). Always preserve original functionality while adding meaningful motion that enhances user understanding and delight.
