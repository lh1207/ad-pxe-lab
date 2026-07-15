# ad-pxe-lab Vault: LLM Wiki

Mode: B (GitHub / Repository), adapted for an infra/runbook project
Purpose: Architecture and operations knowledge base for the ad-pxe-lab homelab — an Active Directory domain controller plus PXE/WDS/ConfigMgr OS deployment lab running on Hyper-V.
Owner: Levi Huff
Created: 2026-07-14

This vault is scoped to **this repository only**. It is separate from the general-purpose
vault at `~/claude-obsidian` — do not mix notes between the two. Cross-project references
from other repos should point here explicitly if they need ad-pxe-lab context.

## Structure

```
vault/
├── .raw/               # immutable source dumps — drop exports/notes here to ingest
├── wiki/
│   ├── index.md        # master catalog of all pages
│   ├── log.md           # append-only chronological record of operations
│   ├── hot.md            # ~500-word recent-context cache
│   ├── overview.md       # executive summary of the lab project
│   ├── modules/           # one note per runbook phase (host prep, AD/DNS/DHCP, WDS/PXE, GPO, golden image, SCCM, OSD handoff)
│   ├── components/        # reusable scripts & artifacts (New-LabVM, New-LabSwitch, unattend files, etc.)
│   ├── decisions/          # ADRs — architecture decision records
│   ├── dependencies/       # Hyper-V, Windows Server/11 ISOs, PowerShell modules, SCCM prereqs
│   ├── flows/               # PXE boot flow, OSD imaging flow, GPO application flow
│   └── meta/                 # lint reports, conventions
├── _templates/                # note templates for each type above
└── CLAUDE.md                  # this file
```

## Conventions

- All notes use YAML frontmatter: `type`, `status`, `created`, `updated`, `tags` (minimum).
- Wikilinks use `[[Note Name]]` format: filenames are unique, no paths needed.
- `.raw/` contains source documents: never modify them.
- `wiki/index.md` is the master catalog: update on every ingest.
- `wiki/log.md` is append-only: never edit past entries. New entries go at the TOP.
- `wiki/hot.md` is a cache, not a journal — overwrite it completely after every session.

## Known repo-state caveat

As of 2026-07-14, `main` merged in the full project content (`docs/architecture.md`,
`docs/decisions.md`, `docs/ip-plan.md`, `docs/iso-checklist.md`, `runbooks/00-10-*.md`,
`scripts/*.ps1`) via PR #1. The `_index.md` pages under `wiki/` were pre-seeded with
summaries of that content at scaffold time; full per-page ingestion (one note per module/
decision/component using `_templates/`) is still pending — say "ingest [file]" to do it.

## Operations

- Ingest: drop a source in `.raw/`, say "ingest [filename]"
- Query: ask any question — Claude reads `hot.md` and `index.md` first, then drills in
- Lint: say "lint the wiki" to run a health check
- Archive: move cold sources to `.raw/.archive/` to keep `.raw/` clean
