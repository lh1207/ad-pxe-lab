---
type: meta
title: "Index"
updated: 2026-08-03T23:50:00-04:00
---

# Index

Master catalog of the ad-pxe-lab vault. Update this on every ingest.

## Overview

- [[Overview]] — executive summary of the lab project

## Modules (runbook phases)

See [[Modules Index]].

## Components (scripts & artifacts)

See [[Components Index]].

## Decisions (ADRs)

See [[Decisions Index]].

## Dependencies

See [[Dependencies Index]].

- [[WOLF Hyper-V Host]] — verified Windows Hyper-V execution host with a ready SSH/Codex desktop
  handoff path

## Flows

See [[Flows Index]].

## Meta

See [[Meta Index]] for conventions and lint reports.

- [[Phase 1 Handoff — AD Foundation]] — audited execution handoff for runbooks 01–03, with the
  synchronized runbook corrections and evidence notebook (`docs/handoffs/phase-01-handoff.md`)
  Live execution is complete through runbook 03; the standard pre-phase-04 checkpoint is ready.
  Publication is tracked in [draft PR #4](https://github.com/lh1207/ad-pxe-lab/pull/4).
- [[Phase 4 — WDS PXE and CL02 Deployment]] — completed custom-WinPE WDS PXE transport,
  Windows 11 Enterprise Evaluation deployment to CL02, domain/OU acceptance evidence, and the
  standard pre-phase-05 checkpoint boundary.

## Sources ingested

None yet — `.raw/` is empty. Drop exports/notes there and say "ingest [filename]" to begin.
