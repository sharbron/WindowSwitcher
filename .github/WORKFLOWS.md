# GitHub Workflows Documentation

This document describes the CI/CD workflows configured for the WindowSwitcher project.

## Overview

The project uses GitHub Actions for continuous integration, testing, and release automation. All workflows are located in `.github/workflows/`.

## Workflows

### 1. CI Workflow (`ci.yml`)

**Triggers:**
- Push to `main`, `develop`, or any `claude/**` branch
- Pull requests to `main` or `develop`

**Jobs:**

#### `lint`
- Runs SwiftLint with strict mode
- Fails the build if any warnings are found
- Uses: `macos-13` runner

#### `build-and-test`
- Builds both debug and release configurations
- Runs all tests in parallel
- Creates app bundle and verifies it
- Uploads app bundle as artifact (7-day retention)
- Matrix strategy: Xcode 15.0

#### `test-coverage`
- Runs tests with code coverage enabled
- Generates LCOV coverage report
- Displays coverage summary
- Non-blocking if coverage export fails

**Artifacts:**
- `WindowSwitcher-{sha}` - App bundle from each commit

---

### 2. Release Workflow (`release.yml`)

**Triggers:**
- Git tags matching `v*.*.*` (e.g., `v1.1.0`)
- Manual dispatch with version input

**Jobs:**

#### `build-release`
- Runs SwiftLint and all tests
- Builds release configuration
- Creates app bundle and DMG
- Generates SHA-256 checksums
- Creates release notes
- Publishes GitHub release with assets (for tags)
- Uploads artifacts (for manual dispatch)

**Release Assets:**
- `WindowSwitcher-1.0.dmg` - Installer
- `checksums.txt` - SHA-256 verification
- Release notes (auto-generated)

**Usage:**

```bash
# Create a release via tag
git tag v1.1.0
git push origin v1.1.0

# Or use GitHub UI
# Actions → Release → Run workflow → Enter version
```

---

### 3. PR Checks Workflow (`pr-checks.yml`)

**Triggers:**
- Pull request opened, synchronized, or reopened

**Jobs:**

#### `pr-validation`
- Quick build check (debug mode)
- Runs all tests in parallel
- Checks for TODO/FIXME comments in changed files
- Scans for large files (>1MB)
- Generates PR validation summary

#### `test-coverage-diff`
- Runs tests with coverage
- Reports current coverage stats
- Provides coverage context in PR

**PR Summary:**
Automatically adds validation summary to PR conversation.

---

### 4. Nightly Build Workflow (`nightly.yml`)

**Triggers:**
- Scheduled: Daily at 2 AM UTC
- Manual dispatch

**Jobs:**

#### `nightly-build`
- Full build (debug + release)
- Runs all tests
- Executes sanitizer checks (thread, address)
- Performance benchmark tests
- Memory leak detection
- Creates nightly DMG
- Uploads build artifacts (7-day retention)
- Notifies on failure

**Artifacts:**
- `WindowSwitcher-nightly-{run_number}`

---

## Runner Configuration

All workflows use **macOS 13 (Ventura)** runners to match the minimum supported OS version.

**Runner:** `macos-13`
- Xcode 15.0
- Swift 5.9
- macOS 13.0 SDK

---

## Best Practices

### For Contributors

1. **Before Pushing:**
   ```bash
   # Run locally to catch issues early
   swiftlint
   swift test
   swift build -c release
   ```

2. **Pull Requests:**
   - CI must pass before merging
   - Address SwiftLint warnings
   - Ensure tests pass
   - Check for TODO/FIXME comments

3. **Commits:**
   - Use descriptive commit messages
   - Reference issues when applicable
   - Keep commits focused and atomic

### For Maintainers

1. **Releases:**
   - Always run tests before tagging
   - Use semantic versioning (MAJOR.MINOR.PATCH)
   - Update version in `Info.plist` before release
   - Tag format: `v1.1.0`

2. **Merge Strategy:**
   - Require PR approval
   - Require CI to pass
   - Squash or rebase merge (keep history clean)

3. **Monitoring:**
   - Check nightly build status regularly
   - Address failing workflows promptly
   - Review coverage trends

---

## Workflow Files

| File | Purpose | Frequency |
|------|---------|-----------|
| `ci.yml` | Build, test, lint on every push | Per push/PR |
| `release.yml` | Create releases and DMG | On tag or manual |
| `pr-checks.yml` | Fast feedback for PRs | Per PR update |
| `nightly.yml` | Comprehensive checks | Daily at 2 AM UTC |

---

## Environment Variables

Currently, no secrets are required. Future additions might include:

- `APPLE_DEVELOPER_ID` - For code signing (when implemented)
- `NOTARIZATION_PASSWORD` - For app notarization
- `SLACK_WEBHOOK` - For build notifications

---

## Troubleshooting

### CI Failing on SwiftLint

**Problem:** SwiftLint fails with warnings in strict mode.

**Solution:**
```bash
# Fix locally
swiftlint --fix
swiftlint autocorrect

# Or adjust .swiftlint.yml rules
```

### Tests Timing Out

**Problem:** Tests exceed timeout.

**Solution:**
- Check for infinite loops in test code
- Reduce test concurrency: `swift test --num-workers 1`
- Add timeout configuration in Package.swift

### App Bundle Not Created

**Problem:** `create_app.sh` fails in CI.

**Solution:**
- Ensure script has execute permissions: `chmod +x create_app.sh`
- Check for path issues (use absolute paths if needed)
- Verify Info.plist exists and is valid

### Release Workflow Not Triggering

**Problem:** Tag pushed but workflow doesn't run.

**Solution:**
- Verify tag format: `v*.*.*` (must start with 'v')
- Check workflow permissions in repository settings
- Ensure workflows are enabled for the repository

---

## Performance

### Typical Workflow Times

| Workflow | Duration | Runner Cost |
|----------|----------|-------------|
| CI (full) | ~5-8 min | Low |
| PR Checks | ~3-5 min | Low |
| Release | ~8-12 min | Medium |
| Nightly | ~10-15 min | Medium |

---

## Future Enhancements

### Planned Improvements

- [ ] Add code coverage reporting to PRs
- [ ] Integrate with Codecov or Coveralls
- [ ] Add performance regression detection
- [ ] Code signing automation
- [ ] Notarization workflow for signed builds
- [ ] Slack/Discord notifications
- [ ] Dependency vulnerability scanning
- [ ] Auto-update changelog generation

### Nice-to-Have

- [ ] Auto-assign reviewers based on file changes
- [ ] Label PRs based on changed files
- [ ] Stale PR/issue management
- [ ] Automated version bumping
- [ ] Release draft creation
- [ ] Beta distribution via TestFlight alternative

---

## Security

### Workflow Permissions

All workflows use minimal permissions:

```yaml
permissions:
  contents: read  # Read repository
  # write only for releases
```

### Best Practices

1. Never commit secrets to workflows
2. Use GitHub Secrets for sensitive data
3. Limit workflow permissions to minimum required
4. Review third-party actions before use
5. Pin action versions to specific commits (when critical)

---

## Support

### Getting Help

- **Workflow issues:** Check the Actions tab for detailed logs
- **SwiftLint errors:** See `.swiftlint.yml` configuration
- **Build failures:** Review `create_app.sh` and `create_dmg.sh`
- **Test failures:** Check test output for specific failures

### Useful Links

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Swift Package Manager](https://swift.org/package-manager/)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [Xcode Build Settings](https://developer.apple.com/documentation/xcode/build-settings-reference)

---

*Last Updated: 2025-11-08*
*WindowSwitcher v1.1*
