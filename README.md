# gods-eye-view
created bye -pamudmurthy jaya chaithanbya

## Fix: `cp` agent files into `~/.claude/agents/` fails on Windows PowerShell

**Symptom**

```text
PS C:\Users\JAYA CHAITHANYA> cp everything-claude-code/agents/*.md ~/.claude/agents/
cp : The directory name is invalid.
At line:1 char:1
+ cp everything-claude-code/agents/*.md ~/.claude/agents/
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Copy-Item], IOException
    + FullyQualifiedErrorId : System.IO.IOException,Microsoft.PowerShell.Commands.CopyItemCommand
```

**Cause** — `cp` in PowerShell is an alias for `Copy-Item`, and unlike the
Unix `cp` it never creates the destination directory. If
`%USERPROFILE%\.claude\agents` does not exist yet (it doesn't on a fresh
machine), the copy throws `System.IO.IOException: The directory name is
invalid`. `~` itself is fine — PowerShell expands it to `$HOME`; only the
missing target folder is the problem.

**Fix (one line)** — create the folder first, exactly like the `mkdir -p`
step in ECC's own documented manual install:

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.claude\agents" | Out-Null
Copy-Item -Path ".\everything-claude-code\agents\*.md" -Destination "$HOME\.claude\agents\"
```

**Or use the helper in this repo** (idempotent, reports what it did, validates
the copied files):

```powershell
.\scripts\install-ecc-agents.ps1 -Source .\everything-claude-code\agents
```

See [`scripts/install-ecc-agents.ps1`](scripts/install-ecc-agents.ps1) for the
full options (`-Force`, `-Project`, `-Destination`).

**Notes**

- `affaan-m/everything-claude-code` was renamed to
  [`affaan-m/ECC`](https://github.com/affaan-m/ECC). Existing clones keep
  working through GitHub's redirect; new clones should use the new URL.
- The checkout's `agents/` folder is flat: 71 `.md` files, each starting with
  YAML front matter (`name`, `description`, `tools`, `model`). A flat copy is
  all Claude Code needs.
- For a full install prefer `.\install.ps1 --target claude` or
  `/plugin install ecc@ecc`. Do not stack a manual agent copy on top of either
  one — duplicate agents across scopes conflict.
- Agents land in `%USERPROFILE%\.claude\agents` (global) or
  `<repo>\.claude\agents` (project-local). Restart Claude Code or run
  `/agents` afterwards to pick them up.
