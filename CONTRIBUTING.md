# Contributing to rimshot

Thanks for wanting to make developers laugh! Here's how to contribute.

## Adding Jokes (easiest contribution)

1. Fork the repo
2. Add your joke to `jokes/<lang>.txt` (one joke per line)
3. Open a PR

### Joke guidelines

- **One joke per line** — no multi-line jokes
- **Keep it short** — under 200 characters is ideal, max 300
- **Developer/tech humor only** — programming, git, CS, IT, hardware, etc.
- **No offensive content** — no sexism, racism, homophobia, or personal attacks
- **No duplicates** — check if the joke already exists (`grep -i "your keyword" jokes/en.txt`)
- **Lines starting with `#` are comments** — use them sparingly for section headers if needed
- **No trailing whitespace**

### Adding a new language

1. Create `jokes/<lang-code>.txt` (use [IETF language tags](https://en.wikipedia.org/wiki/IETF_language_tag): `de`, `it`, `ja`, `ko`, etc.)
2. Add the comment header (see existing files for format)
3. Add at least 10 jokes
4. Update `README.md` (Joke Packs table)
5. Both the hook script and installer auto-discover languages from the `jokes/` directory — no code changes needed

## Code Contributions

### Setup

```bash
git clone https://github.com/dbfarias/rimshot.git
cd rimshot
make test    # Run tests
make lint    # Run shellcheck
```

### Guidelines

- **Bash 4+** compatible
- **`set -euo pipefail`** in all scripts
- **No `eval`** — never, under any circumstances
- **No network calls** — the hook script must work offline
- **`jq` is allowed** in all scripts (required for JSON output and safe JSON manipulation)
- Falls back gracefully to stderr-only if `jq` is absent
- Pass **shellcheck** with no warnings
- Add tests for new features in `tests/test_rimshot.sh`

### Commit messages

```
<type>: <description>

Types: feat, fix, docs, test, chore, ci
```

Examples:
- `feat: add German joke pack`
- `fix: handle missing jokes directory gracefully`
- `docs: add FAQ about performance`
- `test: add cooldown validation test`

## PR Process

1. Fork and create a branch (`feat/german-jokes`, `fix/cooldown-bug`)
2. Make your changes
3. Run `make test && make lint`
4. Open a PR with a clear description
5. Wait for review

## Reporting Issues

Use GitHub Issues. For joke submissions, you can also just open a PR directly.

## Code of Conduct

Be kind. Write jokes, not insults. We're here to make developers smile.
