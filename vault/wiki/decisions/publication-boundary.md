---
type: decision
title: "Lab Publication Boundary"
created: 2026-10-28
updated: 2026-10-28
tags: [publication, git, evidence, secrets]
status: accepted
related: ["[[Decisions Index]]", "[[Phase 5 — Windows Host Execution Handoff]]"]
---

# Lab Publication Boundary

The operator instructs Codex to publish the same artifact categories published in prior lab
phases and keep the previously excluded categories local. This is project-specific guidance
for the public `lh1207/ad-pxe-lab` repository, not blanket authorization for other destinations.

## Verified precedent

- [PR #3](https://github.com/lh1207/ad-pxe-lab/pull/3), merge `2698a02`: reviewed scripts/runbooks,
  lab notebook, readable execution/assertion transcripts and project wiki. Its body explicitly
  excludes local `.codex-*.ps1` wrappers, diagnostics, recovery and orchestration files.
- [PR #4](https://github.com/lh1207/ad-pxe-lab/pull/4), merge `37d7596`: AD/group/AGDLP assertions,
  host boundary and checkpoint summaries, notebook/wiki updates; local wrappers stay excluded.
- [PR #5](https://github.com/lh1207/ad-pxe-lab/pull/5), merge `dbe3959`: reviewed repair code,
  runbooks, canonical text assertions, curated PNG screenshots and wiki publication records.
  Its body explicitly states that no credential values are stored.

## Apply this boundary

Publish reviewed task-specific source, runbooks/handoffs, notebook and project-memory notes,
concise lab assertion transcripts and curated screenshots. Lab hostnames, internal lab domain,
lab identities/groups and configured policy values already occur in those published categories.
Review new evidence for credentials, product keys, tokens, private keys and unrelated personal
content before staging. Do not present a configuration pass as a final checkpoint pass.

Keep credentials and password-bearing answer files out of Git. Keep raw session directories,
downloaded tools, mounted disk/EFI paths, BCD/hive/database artifacts, recovery/queued-runner
scripts and local receipt JSON files local. Full gpresult XML, GPMC HTML/XML exports, backup
manifests and backup trees were not published in PRs #3–#5; keep them local unless the operator
separately requests that new artifact category for this public destination.

An approval rejection is not bypassed by changing tools. Narrow the payload to the authorized
precedent, remove excluded artifacts from every reachable unpushed commit, verify the resulting
branch tree/history, then request normal review again with the new evidence and authorization.
Never force-push or alter already-published history merely to hide an artifact.

If review still rejects the reduced payload, stop and request approval for the exact commit
and named public destination. Matching earlier artifact categories does not itself override
the tool's publication approval requirement.
