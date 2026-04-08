#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "${0}")"

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [<branch>]

  Fetch <branch> from upstream, rebase local copy, and force-push to origin.
  Defaults to the current branch if no argument is given.

  Requires remotes 'upstream' and 'origin' to be configured.

Examples:
  ${SCRIPT_NAME}           # sync current branch
  ${SCRIPT_NAME} main      # sync the main branch
EOF
  exit 0
}

# ─── Helpers ──────────────────────────────────────────────────────────────────
die() {
  echo "Error: $*" >&2
  exit 1
}

# ─── Core ─────────────────────────────────────────────────────────────────────
sync_branch() {
  local branch="$1"

  echo "Fetching upstream/${branch} ..."
  git fetch upstream "${branch}"

  echo "Switching to local branch ${branch} ..."
  git switch "${branch}" 2>/dev/null \
    || git switch -c "${branch}" --track "upstream/${branch}"

  echo "Rebasing on upstream/${branch} ..."
  git pull --rebase upstream "${branch}"

  echo "Pushing to origin/${branch} ..."
  git push --force-with-lease origin "${branch}"

  echo "Done. ${branch} is now synced from upstream and pushed to origin."
}

# ─── Entrypoint ───────────────────────────────────────────────────────────────
main() {
  [[ "${1:-}" == "--help" ]] && usage

  local branch="${1:-$(git branch --show-current)}"

  [[ -n "${branch}" ]] \
    || die "could not detect current branch. Pass a branch name, e.g. ${SCRIPT_NAME} demo"

  git remote get-url upstream >/dev/null 2>&1 \
    || die "remote 'upstream' is not configured"

  git remote get-url origin >/dev/null 2>&1 \
    || die "remote 'origin' is not configured"

  sync_branch "${branch}"
}

main "$@"
