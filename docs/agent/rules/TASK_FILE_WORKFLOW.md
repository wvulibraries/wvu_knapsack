# Task File Workflow Rules

**Last Updated:** 2026-04-06

## Task File State Transitions

- Task files must be moved through the following states:
  1. `backlog` → 2. `active` → 3. `completed`
- Before starting work on a task, move its file from `backlog` to `active`.
- After completing the task, move the file from `active` to `completed`.
- Do not commit or push task files to git; these are for local agent workflow tracking only.

## Commit and Execution Boundaries

- Do not begin any code, documentation, or commit work until the task file is in `active`.
- Only mark a task as completed after all required work is finished and the file is moved to `completed`.

## Enforcement

- Agents must enforce this workflow for all implementation and planning tasks.
- If a task file is not in the correct state, stop and report before proceeding.

---

For questions, see the main agent README or contact the implementation lead.
