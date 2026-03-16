# C4Flow for Codex — Installation

## Prerequisites
- Git installed

## Install

1. Clone the repository:
   ```bash
   git clone https://github.com/tunneleven/C4Flow.git ~/.codex/c4flow
   ```

2. Create the skills symlink:
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/c4flow/skills ~/.agents/skills/c4flow
   ```

3. Restart Codex (quit and relaunch).

## Verify
```bash
ls -la ~/.agents/skills/c4flow
```
Should show a symlink pointing to `~/.codex/c4flow/skills/`.

## Usage
Once installed, invoke in Codex:
- `$c4flow` — Start or resume the development workflow
- `$c4flow-status` — Check workflow progress

## Update
```bash
cd ~/.codex/c4flow && git pull
```
Skills update instantly through the symlink.

## Uninstall
```bash
rm ~/.agents/skills/c4flow
rm -rf ~/.codex/c4flow
```
