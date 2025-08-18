ULTRA THINK

## INSTRUCTIONS

- Examine commits from either:
   - last 2 working days: <run>git log --since=2.days --author="$(git
 config user.name)" --format="%h" --no-merges</run>
   - last 3 working days (over weekend): <run>git log --since=3.days
 --author="$(git config user.name)" --format="%h" --no-merges</run>
- Group by day (most recent first)
- Combine related commits into single bullet
- Ensure all days provided are covered
- Show days in cronological order

## STYLE

Brief bullet points:

- Max 15 words per bullet
- Format: [Component]: [Action/Result]
- Group by: Features > Fixes > Refactors > Chores
- Skip implementation details

## FORMAT

```md
## <Day of Week>

- Component: Action taken
- Component: Action taken

[Blockers: <specific issue needing help>]
```

## EXAMPLE OUTPUT

```md
## Thursday
- Annual Goals: Refactored grid UI
- Audit Trail: Added collapsible layouts
- CI/CD: Fixed lockfile issues

[Blockers: None]

5. Define blockers clearly

## NOTES
- Blockers = issues preventing progress that need team help
- If no commits found for a day, note "No commits"
