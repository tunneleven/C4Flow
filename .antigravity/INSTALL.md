# C4Flow for Antigravity IDE — Installation

## Prerequisites
- Git installed

## Install

1. Clone the C4Flow repository:
   ```bash
   git clone https://github.com/tunneleven/C4Flow.git ~/.antigravity/c4flow
   ```

2. Copy the skills into your project:
   ```bash
   mkdir -p .agents/skills
   cp -r ~/.antigravity/c4flow/skills/* .agents/skills/
   ```

3. Restart Antigravity IDE.

## Verify

```bash
ls .agents/skills/
```

You should see the C4Flow skill folders (c4flow, code, design, spec, etc.).

## Usage

Once installed, tell Antigravity:
- "start c4flow workflow for [feature idea]" — Start or resume the development workflow
- "check c4flow status" — Check workflow progress

## Update

Pull the latest changes and re-copy:
```bash
cd ~/.antigravity/c4flow && git pull
cp -r ~/.antigravity/c4flow/skills/* /path/to/your/project/.agents/skills/
```

Replace `/path/to/your/project` with your actual project path.

## Uninstall

1. Remove the copied skills from your project:
   ```bash
   rm -rf .agents/skills/c4flow .agents/skills/code .agents/skills/design \
          .agents/skills/spec .agents/skills/research .agents/skills/beads \
          .agents/skills/tdd .agents/skills/test .agents/skills/e2e \
          .agents/skills/review .agents/skills/verify .agents/skills/pr \
          .agents/skills/merge .agents/skills/deploy .agents/skills/infra \
          .agents/skills/init .agents/skills/pr-review
   ```

2. Remove the cloned repository:
   ```bash
   rm -rf ~/.antigravity/c4flow
   ```
