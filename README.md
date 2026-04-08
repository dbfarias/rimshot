# rimshot 🥁

> *ba-dum-tss!* Developer jokes injected into Claude's context while it works.

**rimshot** is a [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks) that injects random developer jokes into Claude's context before each tool call. Claude receives the joke as `additionalContext` and naturally weaves it into the conversation — turning boring "Thinking..." moments into comedy breaks.

### What it looks like

```
You: fix the login bug

Claude: 🥁 An SQL query walks into a bar, walks up to two tables and asks, 'Can I join you?'

Looking at the auth module...
```

Claude sees the joke and shares it with you. The jokes appear between your requests and Claude's responses — a little comic relief while it works.

## Features

- **Claude-native**: Jokes arrive as `additionalContext` — Claude sees them and shares naturally
- **Multi-language**: Ships with 210+ jokes in EN, pt-BR, ES, and FR
- **Non-intrusive**: Configurable frequency and cooldown to avoid noise
- **Safe**: No eval, no network calls, strict mode, `trap` guarantees exit 0
- **Easy to contribute**: Add a joke = add a line to a .txt file

## Quick Start

### Requirements

- **bash** 4+
- **jq** (used by install/uninstall and for JSON output in the hook)

### Install

```bash
git clone https://github.com/dbfarias/rimshot.git
cd rimshot
bash install.sh
```

With options:

```bash
bash install.sh --lang pt-BR --frequency 50 --cooldown 5
```

### Uninstall

```bash
bash uninstall.sh
```

### Test before installing

```bash
# See a random joke right now
bash scripts/rimshot.sh < /dev/null

# Run the test suite
make test
```

## Configuration

After installation, edit `~/.claude/rimshot/rimshot.conf`:

```bash
# Language for jokes (en, pt-BR, es, fr)
LANG=en

# Percentage chance of showing a joke per tool call (0-100)
FREQUENCY=30

# Minimum seconds between jokes (0 to disable)
COOLDOWN=10
```

### Environment overrides

Environment variables take precedence over the config file:

```bash
export RIMSHOT_LANG=pt-BR
export RIMSHOT_FREQUENCY=100   # every tool call
export RIMSHOT_COOLDOWN=0      # no cooldown
```

### Language auto-detection

If no language is explicitly set, rimshot reads your system's `$LANG` variable and maps it:

| System `$LANG`      | Rimshot language |
| -------------------- | ---------------- |
| `pt_BR.*`            | `pt-BR`          |
| `es.*`               | `es`             |
| `fr.*`               | `fr`             |
| Everything else      | `en`             |

## How It Works

```
  You                Claude Code              rimshot
  ┌────┐            ┌──────────┐            ┌──────────────┐
  │ ask │──────────▶│ Thinking │──PreTool──▶│ rimshot.sh   │
  │    │            │          │            │  ├ frequency? │
  │    │            │          │◀──JSON─────│  ├ cooldown?  │
  │    │            │          │            │  └ 🥁 joke!  │
  │    │◀───joke───│ Claude   │            └──────────────┘
  │    │◀───answer─│ responds │
  └────┘            └──────────┘
```

1. Claude Code triggers a PreToolUse hook before each tool call
2. `rimshot.sh` checks frequency (random chance) and cooldown (time since last joke)
3. If both pass, it picks a random joke and sends JSON with `additionalContext` to stdout
4. Claude receives the joke as context and shares it with you naturally
5. Always exits 0 — never blocks Claude Code

## Joke Packs

| Language | File        | Jokes | Sources                    |
| -------- | ----------- | ----- | -------------------------- |
| English  | `en.txt`    | 85+   | pyjokes, git-jokes, community |
| Portugues | `pt-BR.txt` | 70+   | pyjokes (adapted), community  |
| Espanol  | `es.txt`    | 25+   | pyjokes                    |
| Francais | `fr.txt`    | 17+   | pyjokes                    |

See [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for full source credits and licenses.

## Contributing

We love joke contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

**TL;DR**: Add a line to `jokes/<lang>.txt` and open a PR. That's it.

## Development

```bash
# Run tests
make test

# Run shellcheck linter
make lint

# Validate joke files
make validate

# Dry-run install (no changes)
bash install.sh --dry-run
```

## Project Structure

```
rimshot/
├── scripts/
│   └── rimshot.sh          # Hook script (the only thing that runs)
├── jokes/
│   ├── en.txt              # English jokes
│   ├── pt-BR.txt           # Portuguese (Brazil) jokes
│   ├── es.txt              # Spanish jokes
│   └── fr.txt              # French jokes
├── tests/
│   └── test_rimshot.sh     # Test suite
├── install.sh              # Installer (copies files + patches settings.json)
├── uninstall.sh            # Clean uninstaller
├── rimshot.conf.example    # Example configuration
├── Makefile                # Development commands
├── CONTRIBUTING.md         # How to contribute
├── ATTRIBUTIONS.md         # Joke source credits
└── LICENSE                 # MIT
```

## FAQ

**Q: Where do the jokes appear?**
A: Claude receives the joke as context via `additionalContext` and shares it with you in the conversation. You'll see jokes naturally woven into Claude's responses.

**Q: Will this slow down Claude Code?**
A: No. The script reads a text file and picks a random line. It runs in ~5ms.

**Q: What if the script crashes?**
A: It uses `set -euo pipefail` with `trap 'exit 0' ERR`. Even if something unexpected happens, the trap guarantees exit code 0 — it will never block Claude Code.

**Q: Can I control how often jokes appear?**
A: Yes. Set `FREQUENCY` (0-100) in the config. 30 = ~1 in 3 tool calls. Set `COOLDOWN` to minimum seconds between jokes. See [Configuration](#configuration).

**Q: How do I add jokes in my language?**
A: Create `jokes/<lang-code>.txt`, add at least 10 jokes (one per line), and open a PR. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

Joke content is sourced from open-source projects. See [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for details.
