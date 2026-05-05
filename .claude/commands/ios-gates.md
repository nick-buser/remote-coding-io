---
description: Run iOS build + tests for the remote-coding scheme
---

Run the iOS build and test suite for `remote-coding`. Report failures and stop — do not push the branch if anything fails.

```sh
xcodebuild \
  -project remote-coding/remote-coding.xcodeproj \
  -scheme remote-coding \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  build test
```

`-skipPackagePluginValidation` is required so the `OpenAPIGenerator` build-tool plugin runs headlessly (Xcode 16+ otherwise prompts for trust). `-skipMacroValidation` quiets the same gate for any macro packages.

If `iPhone 17` is not installed, run `xcrun simctl list devices available` and substitute the most recent installed iPhone simulator. If the build succeeds but tests fail, treat that as a gate failure — surface the failing test name and assertion, do not proceed to push.

When the iOS project layout changes (new scheme, renamed target, additional test target), update both this command and the matching snippet under `### Verifying iOS work` in `claude.md` / `AGENTS.md`.
