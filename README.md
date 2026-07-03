# Kura Pages

A GitHub Action that turns your repo's `docs/` Markdown into a searchable, agent-native docs
site with [Kura](https://kura.build) and deploys it to GitHub Pages. Add one `kura.toml`, one
workflow, and your docs get a real site at `https://<owner>.github.io/<repo>/`.

## Usage

```yaml
name: docs
on:
  push:
    branches: [main]
    paths: ["docs/**", "kura.toml"]
permissions:
  contents: write
concurrency:
  group: pages
  cancel-in-progress: false
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: kurajs/pages@v1
```

Add a `kura.toml` at the repo root (site name, nav, deploy subpath). The action reads it, renders
`docs/` into a static site, and publishes to the `gh-pages` branch.

## Inputs

| input | default | description |
|-------|---------|-------------|
| `config` | `kura.toml` | Path to the Kura config. |
| `docs` | `docs` | Docs source directory to render. |
| `homepage` | `auto` | `auto` (index.md if present, else README.md), `readme`, `index`, or `landing`. |
| `base-path` | `auto` | Auto-detected: a repo-level custom domain or `owner.github.io` page → `""`; a project page → `/<repo>`. Override with an explicit value if needed. |
| `embed` | `false` | Build the semantic (vector) index too; `false` keeps the fast, model-free BM25 client search. |
| `deploy` | `true` | Deploy to `gh-pages`; set `false` to only build (see the `dir` output). |
| `cli-version` / `docs-version` | latest 0.0.x | Pin `@kurajs/cli` / `@kurajs/docs`. |
| `bun-version` | `1.3.14` | Bun version. |

## What it does

- Builds in an isolated dir, so your repo root is never touched (works even if the repo is itself an app).
- Uses `docs/README.md` (or `docs/index.md`) as the homepage.
- Ships client-side search plus `.md`, `.json`, `/llms.txt`, and MCP surfaces for AI agents.

## Custom domains

You don't configure `base_path` by hand. The action detects how the site is served and sets it: a repo-level custom domain (a `CNAME` on `gh-pages`) or an `owner.github.io` page is served at the root (`""`); a normal project page is served under `/<repo>`. It also carries an existing `CNAME` into every deploy, so a custom domain survives redeploys.

## Development

CI (`.github/workflows/ci.yml`) runs on every push and PR:

- **lint** — [actionlint](https://github.com/rhysd/actionlint) (workflows), yamllint (`action.yml` + workflows), shellcheck (`scripts/*.sh`), and ruff (`scripts/*.py`).
- **test** — a self-test that builds `test/fixture/` through the action (`uses: ./`) and asserts the rendered pages plus the `base_path` prefix for both a project-page (`/foo`) and a root (`""`) deploy.

The build logic lives in `scripts/build.sh` + `scripts/set_base_path.py` (extracted from `action.yml` so it can be shellcheck'd and read cleanly).
