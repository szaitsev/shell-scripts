# sync-upstream-branch

Fetch a branch from `upstream`, rebase the local copy onto it, and force-push to `origin`.

Useful when you maintain a fork and need to keep a branch in sync with the source repo.

## Usage

```
sync-upstream-branch.sh [<branch>]
```

Omit `<branch>` to use the current branch.

## Requirements

Both `upstream` and `origin` remotes must be configured:

```bash
git remote add upstream https://github.com/original/repo.git
```

## Examples

```bash
# Sync the current branch
./sync-upstream-branch.sh

# Sync a specific branch
./sync-upstream-branch.sh main
./sync-upstream-branch.sh feature/foo
```

## What it does

1. `git fetch upstream <branch>` — fetches latest from upstream
2. `git switch <branch>` — switches to the branch (creates it tracking upstream if it doesn't exist locally)
3. `git pull --rebase upstream <branch>` — rebases local commits on top of upstream
4. `git push --force-with-lease origin <branch>` — pushes to your fork, refusing if someone else pushed in the meantime
