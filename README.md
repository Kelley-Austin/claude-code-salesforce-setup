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
5. Follow the two final on-screen logins (Claude + Salesforce).

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

## What the script does NOT do (on purpose)

Two steps require the actual person and cannot be safely automated:

- **Claude Code login** — opens a browser to authenticate the user's account.
- **Salesforce org login** — opens a browser to connect their org.

The installer finishes by printing clear, copy-paste instructions for both.

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
