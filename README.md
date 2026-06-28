# Claude Code for Salesforce — Mac Setup Assistant

A one-command installer that sets up everything a non-technical user needs to
run **Claude Code with Salesforce** on a Mac. No prior coding or setup
knowledge required.

## What it installs

| # | Component | Why |
|---|-----------|-----|
| 1 | Xcode Command Line Tools | git + compilers (base requirement) |
| 2 | Homebrew | package manager used to install the rest |
| 3 | Node.js | runtime that Claude Code runs on |
| 4 | Claude Code CLI | the AI coding assistant |
| 5 | Visual Studio Code | the editor |
| 6 | Salesforce CLI (`sf`) | talk to Salesforce orgs |
| 7 | Java (Temurin JDK) | required by the Salesforce VS Code extensions |
| 8 | VS Code extensions | Salesforce Extension Pack + Claude Code |

The script is **idempotent** — safe to run as many times as you like. Anything
already present is detected and skipped. It supports both **Apple Silicon**
(M1/M2/M3/M4) and **Intel** Macs automatically.

## For end users — how to run it

1. Open the **Terminal** app (press `Cmd + Space`, type `Terminal`, press Enter).
2. Paste this single line and press Enter:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Kelley-Austin/claude-code-salesforce-setup/main/install.sh | bash
   ```

3. When asked, type your **Mac password** (it won't show as you type — that's normal).
4. Wait. It takes about 10–20 minutes.
5. At the end, VS Code opens automatically and a new Terminal window pops up
   to guide the two browser logins (Salesforce, then Claude). Just follow it.

## Hosting the one-liner

This installer is hosted publicly in this repository, so the raw URL works for
everyone with no authentication:

```
https://raw.githubusercontent.com/Kelley-Austin/claude-code-salesforce-setup/main/install.sh
```

To **update the installer for everyone**, just commit a new `install.sh` to
`main` — users always fetch the latest version on their next run. No
redistribution needed; the one-liner stays the same.

> Tip: a short link (e.g. a company URL shortener pointing at the raw URL)
> makes it friendlier to paste.

## Guided setup window (auto-launched)

When everything is installed, the script opens a fresh Terminal window with a
**step-by-step menu**. Every step is optional, so users pick only what they need:

1. **Salesforce connection** — choose one:
   - **Use an org you're already logged into** — shows a **numbered list** of the
     connected orgs; the user just types the number (no alias/username to type).
   - **Log in to a new org** — asks the org type (**Production**, **Sandbox**, or
     **Custom domain**, where they paste the My Domain URL) and runs
     `sf org login web --instance-url … --set-default`.
   - **Skip Salesforce for now.**

2. **Create a project folder?** `[Y/n]` — if yes, asks for a name and creates the
   project in **`~/Documents`** (`sf project generate`). The chosen org is saved
   as the project's default.

3. **Download (retrieve) the org's metadata?** `[Y/n]` — only offered when an org
   is connected and a project was created. If yes, it builds a starter
   `manifest/package.xml` (Apex classes/triggers, Visualforce, LWC, Aura, Custom
   Objects, Flows, Layouts, Permission Sets, Tabs, Apps, Static Resources) and
   runs `sf project retrieve start`. Choosing **no** leaves an empty project you
   can retrieve into later.

4. **Opens VS Code** — in the new project folder if one was created, otherwise a
   plain window. The Claude Code extension loads here. The installer also turns
   off VS Code's *Workspace Trust* prompt (`security.workspace.trust.enabled:
   false`) so company projects open ready to use instead of in Restricted Mode
   (where the Salesforce extensions would be disabled).

5. **Starts Claude** (`claude`) — opens the browser to sign in if needed. This
   also signs in the VS Code extension (shared credentials).

A reusable **"Finish Claude + Salesforce Setup.command"** file is left on the
Desktop, so anyone can re-run any of these steps (log in, create another project,
retrieve) with a double-click.

> Why a separate Terminal window? Those tools need a real interactive terminal,
> which a piped `curl | bash` cannot provide — so the script launches one.

## Troubleshooting

- A full log is saved to `~/Library/Logs/claude-salesforce-setup.log`.
- If something fails, re-running the script is safe and usually resolves
  transient network issues.
- If `claude`, `sf`, or `code` "aren't found" right after install, open a
  **new** Terminal window (the PATH refreshes there).

## Project layout

```
.
├── install.sh   # the installer (single self-contained file)
└── README.md    # this file
```
