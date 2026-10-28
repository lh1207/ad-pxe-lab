# Phase 05 GPO report rendering status

The genuine local Microsoft GPMC exports were inspected as the source evidence:

- `docs/phase-05-session/gpo-configuration-backup-20261028-033904897/post-gui-20261028-033904897/3d5e8657-4b90-4364-b026-2bad36ea027f.html` — `GPO-C-Workstation-Baseline`; its source contains the enabled, non-enforced `Workstations` link and the approved baseline settings. SHA-256: `0E52C61FD647824202F7F69EEA424F0BDDF3AE7607C4914FD4DC5CFDA0B53A5C`.
- `docs/phase-05-session/gpo-configuration-backup-20261028-033904897/post-gui-20261028-033904897/07473a8a-8c5f-4296-b09a-c7e7f6149ef7.html` — `GPO-U-IT-DriveMaps`; its source contains the enabled, non-enforced `Users` link, `\\DC01\HRShare`, and item-level `HUFFLAB\RG-HR-Staff` targeting. SHA-256: `31AC5275C755692698148F99B515F02F9E678C9CCFD3AF56DEDA78885D87AEB5`.

No PNG render was created. Edge and Chrome headless executables are unavailable on WOLF; Firefox is installed, but its headless screenshot invocation exits with code 1 without producing an image in this restricted session. The source exports remain unchanged and are the authoritative evidence. This status must not be interpreted as a visual screenshot assertion.
