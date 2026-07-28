# git-screen-saver (gitscrnsvr)

A GNOME idle-triggered screensaver daemon that replays a git repo's commit
history using [gitlogue](https://github.com/unhappychoice/gitlogue) whenever
you step away, then locks the screen the moment you touch keyboard or mouse
again.

## Requirements

- A GNOME session (uses `gdbus`/Mutter's idle monitor, GNOME SessionManager,
  and GNOME ScreenSaver over D-Bus) with `systemd --user` and `gnome-terminal`.
- [`gitlogue`](https://github.com/unhappychoice/gitlogue) installed by any
  method, see its
  [installation docs](https://github.com/unhappychoice/gitlogue/blob/main/docs/installation.md).
  `gitscrnsvr` looks for it on `PATH` first, then in every location gitlogue's
  own docs describe (`~/.local/bin`, `~/.cargo/bin`, Homebrew/Linuxbrew,
  pacman's `/usr/bin`, manual drops in `/usr/local/bin`). If it's somewhere
  unusual, set `GITLOGUE=/path/to/gitlogue` in the config file below.

## Install

```bash
git clone https://github.com/PB811/git-screen-saver.git
cd git-screen-saver
./install.sh
```

`install.sh` checks for required dependencies, detects `gitlogue`, and
interactively asks for the git repo you want replayed as a screensaver
(defaulting to the current directory if it's a repo). It's safe to re-run;
it won't overwrite an existing config.

## Configure

Settings live in `~/.config/gitscrnsvr/config.env` (created by `install.sh`),
not in the installed script itself, that keeps `gitscrnsvr update` (below)
safe to run without clobbering your setup. Just open the file and edit it:

```bash
$EDITOR ~/.config/gitscrnsvr/config.env
```

Every line uses `: "${VAR:=default}"`, so an environment variable already
exported when `gitscrnsvr` starts (e.g. `IDLE_TIMEOUT_MS=10000 gitscrnsvr`)
still wins over whatever's in the file; the file only sets a variable if
it isn't already set.

### Configuration reference

#### Repository

| Variable | Default | What it does |
| --- | --- | --- |
| `REPO_PATH` | *(set during install)* | The git repo whose commit history gets replayed. |

#### gitlogue display flags

`GITLOGUE_FLAGS` is passed straight through to `gitlogue`, so anything it
supports works here. Full docs:
[gitlogue usage](https://github.com/unhappychoice/gitlogue/blob/main/docs/usage.md).

| Flag | Default | What it does |
| --- | --- | --- |
| `--order <MODE>` | `random` here | Playback order: `random`, `asc`, `desc` |
| `--theme <NAME>` | `tokyo-night` | See theme list below |
| `--speed <MS>` | `30` | Typing speed, ms/char (10-100 is a reasonable range) |
| `--author <PATTERN>` | *(none)* | Only replay commits by a matching author |
| `--after <DATE>` / `--before <DATE>` | *(none)* | Restrict to a date range, e.g. `--after "1 week ago"` |
| `--ignore <PATTERN>` | *(none)* | Skip files matching a glob (repeatable) |
| `--ignore-file <PATH>` | *(none)* | Load ignore patterns from a file |
| `--speed-rule <GLOB:MS>` | *(none)* | Per-file-type typing speed, e.g. `--speed-rule "*.json:5"` |
| `--commit <HASH_OR_RANGE>` | *(none)* | Replay one commit or range instead of the whole history |

Available themes: `tokyo-night` (default), `dracula`, `nord`, `gruvbox`,
`catppuccin`, `monokai`, `one-dark`, `ayu-dark`, `everforest`, `fluorite`,
`github-dark`, `material`, `night-owl`, `rose-pine`, `solarized-dark`,
`solarized-light`, `telemetry`.

Example: `GITLOGUE_FLAGS="--order asc --theme dracula --speed 15"`

#### Idle timing

Not written to `config.env` by default (commented out), uncomment or add
any of these to override:

| Variable | Default | What it does |
| --- | --- | --- |
| `IDLE_TIMEOUT_MS` | `300000` (5 min) | How long you must be idle before the screensaver starts |
| `WAKE_THRESHOLD_MS` | `2000` | Idle-ms below this, after launch, counts as "you're back" |
| `LAUNCH_GRACE_SEC` | `8` | Seconds right after launch where idle resets are ignored, so it doesn't instantly dismiss itself |
| `POLL_INTERVAL` | `5` | Seconds between idle checks while waiting to trigger |
| `WAKE_POLL_INTERVAL` | `1` | Seconds between idle checks once the screensaver is active |

To change how long before the screensaver kicks in, for example, add this
line to `config.env`:

```sh
: "${IDLE_TIMEOUT_MS:=600000}"   # 10 minutes
```

#### Advanced

| Variable | Default | What it does |
| --- | --- | --- |
| `GITLOGUE` | *(auto-detected)* | Explicit path to the `gitlogue` binary, only needed if it's installed somewhere `find_gitlogue()` doesn't check |

## Run

```bash
# test manually first (triggers after 10s)
IDLE_TIMEOUT_MS=10000 ~/.local/bin/gitscrnsvr -v

# then run as a background service
systemctl --user enable --now gitscrnsvr.service
journalctl --user -u gitscrnsvr -f
```

## Commands

Flag and bare-word forms both work:

| Flag             | Bare word | Description                                  |
| ---------------- | --------- | --------------------------------------------- |
| `-v`, `--verbose`| `verbose` | Print idle time/detail every poll cycle       |
| `-V`, `--version`| `version` | Print the installed version                   |
| `--update`       | `update`  | Check GitHub for a newer release and install it |
| `-h`, `--help`   | `help`    | Show usage                                    |

`gitscrnsvr update` (or `--update`) checks the latest GitHub release, and if
newer, stops the systemd service if it's running, replaces the installed
script and service unit, and restarts it. Pass `-y`/`--yes` to skip the
confirmation prompt.

## Uninstall

```bash
./uninstall.sh          # keeps your config
./uninstall.sh --purge  # also deletes ~/.config/gitscrnsvr
```

## Testing

```bash
tests/run_all.sh
```

No test framework dependency, just bash and coreutils. Covers the pure
parsing logic in `gitscrnsvr` (idle/lock-state parsing, version comparison,
release-tag parsing), `find_gitlogue` detection, the CLI surface, and
`install.sh`/`uninstall.sh` behavior, all run against scratch `HOME`
directories and a stubbed `systemctl` so nothing touches the real machine.
Runs in CI on every push and pull request.

## Releasing (maintainers)

1. Bump `VERSION="X.Y.Z"` near the top of `gitscrnsvr` and commit.
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. The `Release` GitHub Actions workflow verifies the tag matches `VERSION`,
   then publishes a GitHub Release with auto-generated notes and the raw
   `gitscrnsvr`, `gitscrnsvr.service`, `install.sh`, and `uninstall.sh` as
   assets, which is what `gitscrnsvr update` downloads from.
