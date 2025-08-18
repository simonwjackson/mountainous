<goal>

</goal>

<info>

component-name:
sanitized-name:

</info>

<definition-of-done>

- Component is placed in the `features/<sanitized-name>/components` directory
- Component has mocks: `features/<sanitized-name>/mocks/*.handlers.ts`
- Component has ladel stories: `features/<sanitized-name>/components/*.stories.tsx`
- Component should have the following states:
  - Focused (Active)
  - Success
  - Error
- Component has en & es locales: `features/<sanitized-name>/locales/*.json`
- Component has functional vitests (if nessicary): `features/<sanitized-name>/**/*.test.ts`
  - We dont test JSX components with vitest, only functions with clear input and output expectations
  - Place tests next to the related implementation
- Component has component tests (playwright): `features/<sanitized-name>/**/*.component.spec.ts`
  - We test ladle stories
  - Use user centric testing: docs/USER-CENTRIC-TESTING.md
  - example: src/shared/components/HelloWorld/HelloWorld.component.spec.ts
- vitest tests are passing. Remember that only
- Create ladle stories
- run `tsc --noEmit` to ensure there are no type errors
- run `just format` to ensure formatting is correct
- run `just lint` to ensure linting is correct
- run `just build` to ensure the app builds
- show me steps to manually validate your work
- Check the `<rootDir>/docs` directory and, if necessary, update the related documentation

</definition-of-done>
