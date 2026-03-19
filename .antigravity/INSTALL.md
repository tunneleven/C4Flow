# C4Flow for Antigravity IDE — Installation

## Prerequisites
- Git installed

## Install

### Workspace (current project only)

1. Clone the repository:
   ```bash
   git clone https://github.com/tunneleven/C4Flow.git ~/.antigravity/c4flow
   ```

2. Create the skills symlink in your project:
   ```bash
   mkdir -p .agents/skills
   ln -s ~/.antigravity/c4flow/skills .agents/skills/c4flow
   ```

3. Restart Antigravity.

### Global (all workspaces)

1. Clone the repository:
   ```bash
   git clone https://github.com/tunneleven/C4Flow.git ~/.antigravity/c4flow
   ```

2. Create the global skills symlink:
   ```bash
   mkdir -p ~/.gemini/antigravity/skills
   ln -s ~/.antigravity/c4flow/skills ~/.gemini/antigravity/skills/c4flow
   ```

3. Restart Antigravity.

## Verify
```bash
ls -la .agents/skills/c4flow
# or for global:
ls -la ~/.gemini/antigravity/skills/c4flow
```
Should show a symlink pointing to `~/.antigravity/c4flow/skills/`.

## Usage
Once installed, tell Antigravity:
- "start c4flow workflow for [feature idea]" — Start or resume the development workflow
- "check c4flow status" — Check workflow progress

## Update
```bash
cd ~/.antigravity/c4flow && git pull
```
Skills update instantly through the symlink.

## Uninstall

### Workspace
```bash
rm .agents/skills/c4flow
rm -rf ~/.antigravity/c4flow
```

### Global
```bash
rm ~/.gemini/antigravity/skills/c4flow
rm -rf ~/.antigravity/c4flow
```
