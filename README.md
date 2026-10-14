# DreamMemory Builder

This public repository owns the GitHub Actions workflow that builds APKs from the private DreamMemory source repository. **It contains build automation, not the app source.**

## Repository responsibilities

- **Private source:** [maoni66/DreamMemory](https://github.com/maoni66/DreamMemory) is the source of truth for Kotlin/Compose code, product documentation, design decisions, and audit history.
- **Public builder:** this repository checks out the private source `main` using the `SOURCE_REPO_TOKEN` secret, runs tests and APK packaging, validates the Room schema contract, signs/verifies the APK, and publishes the result to the private source repo.
- Do not mirror or move application source code into this public repository.

## Mandatory trigger contract

1. A normal push to the private `DreamMemory` repository must **not** trigger Actions. The private `.github/workflows/build-apk.yml` is manual-only (`workflow_dispatch`) and must not contain a `push` trigger.
2. APK automation is triggered by a push to **this public repository's `main` branch that changes `build-request.txt`**. Keep build requests as a dedicated one-file commit where practical; the path filter means other pushes that do not touch this file do not trigger APK automation. The workflow must retain a manual `workflow_dispatch` entry.
3. To request a fresh build, first read the current SHA of private `DreamMemory/main`, then update both the expected SHA and the request text in `build-request.txt`. Committing that file is the automatic trigger.
4. The workflow must record the actual checked-out source SHA and refuse to publish if the private source branch advances during the build. Do not weaken this parity check.
5. Keep the `push.paths` filter limited to `build-request.txt`; ordinary documentation/workflow edits in this public repository should not start expensive APK builds.

## Build and delivery truthfulness

A commit to `build-request.txt` requests a build; it does not prove the workflow started or succeeded. Verify the actual GitHub Actions run, job steps/logs, Room schema check, APK signature verification, and private release before reporting success. Source commit, workflow trigger, build success, APK publication, and device installation are separate milestones.

The source repository's `docs/PROJECT_CONTEXT.md` is the canonical project decision record. Its section **“仓库职责与自动化触发硬规则”** defines this contract and must be kept in sync with this file.
