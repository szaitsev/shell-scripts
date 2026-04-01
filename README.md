# Shell Scripts

Personal collection of bash utility scripts. Each script is self-contained in its own folder with dedicated documentation.

## Structure

```
shell-scripts/
├── CLAUDE.md          ← global conventions (for Claude Code)
├── README.md          ← this file
└── script-name/
    ├── script-name.sh
    └── README.md
```

## Scripts

| Script | Description |
|--------|-------------|
| [ai-local-stack](./ai-local-stack/) | Manage a local AI development stack (Ollama, Open WebUI, etc.) |

## Common conventions

- Bash only, with `set -euo pipefail`
- All scripts support `--help`
- Errors go to stderr; output to stdout
- Each folder has its own README with full usage docs

## Usage

```bash
# Run directly
bash script-name/script-name.sh [args]

# Or after making executable
chmod +x script-name/script-name.sh
./script-name/script-name.sh [args]
```

## Adding a new script

```bash
mkdir my-new-script
touch my-new-script/my-new-script.sh
chmod +x my-new-script/my-new-script.sh
touch my-new-script/README.md
# optionally: touch my-new-script/CLAUDE.md
```

Then update the Scripts table above.
