---
description: Standardized development workflow for boring.notch
---

# Git Flow: Branching & Deployment Strategy

To maintain a stable, high-quality codebase, follow this structured branching strategy.

## 1. Topic Branch (Active Development)
**Naming Convention:** `feature/xxx`, `fix/xxx`, `perf/xxx`, `refactor/xxx`
- Always create a new branch from `developer` for any new work.
- Perform all research, implementation, and verification within this branch.
- **Rules:**
  - Build must stay green.
  - Zero files > 300 lines.
  - No new singletons.
  - Update `task.md` and `walkthrough.md` as you progress.

## 2. Integration (`developer`)
**Role:** The "next release" candidate branch.
- Once a topic branch is verified and code-reviewed, merge it into `developer`.
- **Workflow:**
  1. `git checkout developer`
  2. `git pull origin developer`
  3. `git merge [your-branch]`
  4. `git push origin developer`

## 3. Production (`main`)
**Role:** Stable, public-facing release branch.
- Merge from `developer` to `main` only when a set of features is fully stable and ready for a public release.
- Typically happens at the end of a major Phase (e.g., end of Phase 10).
- **Workflow:**
  1. `git checkout main`
  2. `git merge developer`
  3. `git tag -a vX.Y.Z -m "Release message"`
  4. `git push origin main --tags`
