#!/usr/bin/env bash
# Install repository Git hooks for pre-commit (just check) and commit-msg (Conventional Commits).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
hooks_dir="$repo_root/.git/hooks"

if [[ ! -d "$repo_root/.git" ]]; then
  echo "error: .git directory not found; run git init first" >&2
  exit 1
fi

mkdir -p "$hooks_dir"

cat > "$hooks_dir/pre-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec just check
EOF

cat > "$hooks_dir/commit-msg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$(git rev-parse --show-toplevel)/scripts/check-commit-message.sh" "$1"
EOF

chmod +x "$hooks_dir/pre-commit" "$hooks_dir/commit-msg"
echo "Git hooks installed in $hooks_dir"

