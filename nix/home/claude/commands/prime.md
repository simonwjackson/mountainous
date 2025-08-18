---
description: Analyze Current Codebase & Await Instructions
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

# Analyze Current Codebase & Await Instructions

<ai_meta>
  <parsing_rules>
    - Process XML blocks first for structured data
    - Execute instructions in sequential order
    - Analyze existing code thoroughly
  </parsing_rules>
  <file_conventions>
    - encoding: UTF-8
    - line_endings: LF
    - indent: 2 spaces
    - markdown_headers: no indentation
  </file_conventions>
</ai_meta>

## Overview

<purpose>
  - Analyze and understand the current codebase
  - Build comprehensive context about the project
  - Wait for specific instructions on what to do next
</purpose>

## Process

<step number="1" name="analyze_codebase">

### Step 1: Analyze Current Codebase

<analysis_areas>
  <project_structure>
    - Directory organization
    - File naming patterns
    - Module structure
    - Build configuration
  </project_structure>
  <technology_stack>
    - Frameworks in use
    - Dependencies (package.json, Gemfile, requirements.txt, etc.)
    - Database systems
    - Infrastructure configuration
  </technology_stack>
  <implementation_state>
    - Completed features
    - Work in progress
    - Authentication/authorization
    - API endpoints
    - Database schema
  </implementation_state>
  <code_patterns>
    - Coding style
    - Naming conventions
    - File organization patterns
    - Testing approach
  </code_patterns>
</analysis_areas>

<instructions>
  ACTION: Thoroughly analyze the existing codebase
  DOCUMENT: Current technologies, features, and patterns
  IDENTIFY: Architectural decisions and patterns
  NOTE: Development progress and project state

  EXECUTE: Directory structure analysis
  ```bash
  # List project directory tree structure (respecting .gitignore)
  nix run nixpkgs#eza -- --tree --all --git-ignore 2>/dev/null
  ```
</instructions>

</step>

<step number="2" name="summarize_and_wait">

### Step 2: Summarize Findings & Await Instructions

<summary_template>
  ## 📊 Codebase Analysis Complete

  I've analyzed your codebase and am ready to help. What would you like me to do?
</summary_template>

<instructions>
  ACTION: Complete codebase analysis
  NOTIFY: User that analysis is complete
  WAIT: For user's specific instructions
</instructions>

</step>

</step>

## Execution Summary

<final_actions>
  <completed>
    - [ ] Codebase analyzed thoroughly
    - [ ] Technologies and patterns identified
    - [ ] Current state documented
    - [ ] Ready for specific instructions
  </completed>
</final_actions>
