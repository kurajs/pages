#!/usr/bin/env bash
# Build a Kura docs site from kura.toml + docs/ in an isolated dir, so the caller's repo root is
# never touched. Driven entirely by env vars set in the composite action's `env:` block, which is
# why shellcheck can't see their assignment.
# shellcheck disable=SC2154
set -euo pipefail

SITE="$RUNNER_TEMP/kura-site"
rm -rf "$SITE"
mkdir -p "$SITE/content/docs"
# Docs become Kura's local content (works even if the caller's repo is itself an app).
cp -R "$DOCS_DIR"/. "$SITE/content/docs/"

# Homepage: prefer an existing index.md; otherwise promote README.md (unless the caller forced a mode).
if [ "$HOMEPAGE" != "index" ] && [ "$HOMEPAGE" != "landing" ] &&
  [ ! -f "$SITE/content/docs/index.md" ] && [ -f "$SITE/content/docs/README.md" ]; then
  mv "$SITE/content/docs/README.md" "$SITE/content/docs/index.md"
fi

# Repo-relative links (../README.md, ../src/x.rs, pruned docs) are handled NATIVELY by kura
# >=0.0.27: each page resolves links from its own source path, against a git-tracked oracle,
# with exact-sha blob URLs (KURA_REPO_ROOT/KURA_SOURCE_MAP above). The old sed pre-fix retired
# after live verification; native covers anchors, subfolders, and non-.md targets it never could.

cp "$CONFIG" "$SITE/kura.toml"

# Detect THIS repo's own custom domain: a repo-level CNAME means it is served at the domain root
# (base_path ""), whereas an owner-level domain leaves project pages under "/<repo>".
git fetch origin gh-pages --depth 1 2>/dev/null || true
CNAME="$(git show FETCH_HEAD:CNAME 2>/dev/null | head -1 | tr -d '[:space:]' || true)"
# Fall back to the Pages API, but only trust it when the call actually succeeds: on a 404 (Pages not
# enabled yet) gh prints the error body to stdout, which must NOT be mistaken for a custom domain.
if [ -z "$CNAME" ] && resp="$(gh api "repos/${REPO}/pages" 2>/dev/null)"; then
  CNAME="$(printf '%s' "$resp" | jq -r '.cname // empty')"
fi

# Derive the deploy base path unless the caller passed one explicitly.
BP="$BASE_PATH_INPUT"
if [ "$BP" = "auto" ]; then
  NAME="${REPO#*/}"
  OWNER="${REPO%%/*}"
  BP="/$NAME"
  if [ "$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]').github.io" ]; then
    BP=""
  fi
  [ -n "$CNAME" ] && BP=""
fi
echo "kura-pages: deploy base_path='$BP' (repo custom domain: ${CNAME:-none})"
KURA_BP="$BP" python3 "$GITHUB_ACTION_PATH/scripts/set_base_path.py" "$SITE/kura.toml"

EMBED_FLAG="--no-embed"
[ "$EMBED" = "true" ] && EMBED_FLAG=""
cat >"$SITE/package.json" <<JSON
{
  "name": "kura-docs-ephemeral", "private": true, "type": "module",
  "scripts": { "build": "kura build $EMBED_FLAG" },
  "dependencies": { "@kurajs/docs": "$DOCS_VERSION", "react": "^19.2.0", "react-dom": "^19.2.0" },
  "devDependencies": {
    "@kurajs/cli": "$CLI_VERSION", "@tailwindcss/node": "^4.3.1", "@tailwindcss/oxide": "^4.3.1",
    "@tailwindcss/typography": "^0.5.20", "@types/react": "^19.2.0", "tailwindcss": "^4.3.1", "typescript": "^5.9.0"
  }
}
JSON

cd "$SITE"
bun install
bun run build

# Preserve the custom-domain CNAME in the published output (survives peaceiris keep_files:false).
if [ -n "$CNAME" ]; then
  printf '%s\n' "$CNAME" >"$SITE/dist/static/CNAME"
  echo "kura-pages: CNAME preserved ($CNAME)"
fi
echo "dir=$SITE/dist/static" >>"$GITHUB_OUTPUT"
