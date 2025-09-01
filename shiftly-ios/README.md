# Shiftly (iOS, SwiftUI + SwiftData)

This repo is auto-prepared to build an **unsigned .ipa** via **GitHub Actions** (macOS runner) and package it for sideloading with tools like FlekSt0re.

## Build
- Trigger **Actions → Build IPA (unsigned)** → Run workflow.
- Download artifact **Shiftly-ipa** → `Shiftly.ipa`.

## Notes
- The build defines `SIDELOAD` to avoid CloudKit/Live Activity entitlements.
- Bundle ID defaults to `com.digilix.shiftly`. Change it in `project.yml` if needed.
