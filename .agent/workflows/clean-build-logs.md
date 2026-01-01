---
description: Clean up build logs from the project directory
---

# Clean Build Logs

This workflow removes build log files that are generated during Xcode builds.

## Steps

// turbo
1. Remove all build log files:
```bash
rm -f build_log*.txt
```

## When to Use

- Before committing changes
- After build verification is complete
- When the project directory feels cluttered
