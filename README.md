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

When everything is installed, the script opens a fresh Terminal window that
guides the user through the rest — no commands to type or remember:

1. **Salesforce login** — asks which org type they're connecting to
   (**Production**, **Sandbox**, or **Custom domain**, where they paste their
   My Domain URL), then opens the browser with the correct endpoint
   (`sf org login web --instance-url … --set-default`).

2. **Project + metadata (optional)** — asks `Create a project and download your
   org's metadata now? [Y/n]`. If yes, it:
   - asks for a **folder name** and creates the project in **`~/Documents`**
     (`sf project generate`),
   - builds a **starter `manifest/package.xml`** covering the common types
     (Apex classes/triggers, Visualforce, LWC, Aura, Custom Objects, Flows,
     Layouts, Permission Sets, Tabs, Apps, Static Resources),
   - **downloads** them with `sf project retrieve start --manifest manifest/package.xml`.

3. **Opens VS Code** — in the new project folder if one was created (otherwise a
   plain window). The Claude Code extension loads here.

4. **Claude login** (`claude`) — opens the browser to sign in. This also signs in
   the VS Code extension (shared credentials).

A reusable **"Finish Claude + Salesforce Setup.command"** file is left on the
Desktop, so anyone can re-run the logins or spin up another project with a
double-click.

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
