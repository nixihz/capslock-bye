# Releasing

GitHub Actions builds CapsLock Bye and publishes signed, notarized DMGs to [GitHub Releases](https://github.com/nixihz/capslock-bye/releases).

## Configure once

In **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded `.p12` containing a Developer ID Application certificate and its private key |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Non-empty password protecting the `.p12` |
| `APPLE_ID` | Apple Account email for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for that account |
| `APPLE_TEAM_ID` | Developer team ID matching the certificate and account |

Export the certificate and private key from Keychain Access. Copy the encoded file with `base64 -i /path/to/DeveloperID.p12 | pbcopy`, then paste it into the secret. Keep the certificate outside the repository.

CI needs no secrets. Releases use GitHub's built-in token, so no personal access token is required. Both workflows use `macos-26` with Xcode 26.6; update their `DEVELOPER_DIR` values together when upgrading.

## Publish

1. Update `CFBundleShortVersionString` in `Resources/Info.plist` and increment `CFBundleVersion`.
2. Commit and push to `main`, then wait for CI to pass.
3. Push a matching version tag, for example:

   ```sh
   git tag -a v1.0.0 -m "CapsLock Bye 1.0.0"
   git push origin v1.0.0
   ```

The release workflow tests, builds both architectures, signs, notarizes, and verifies the DMG. It uploads all assets to a draft release before making it public. Tags must match the plist and use `v<major>.<minor>.<patch>`. Forks must update the workflow's repository check to publish their own releases.

Each release includes versioned and stable DMG filenames with SHA-256 checksums. The website and READMEs use these stable links, which become available after the first release:

- [Latest DMG](https://github.com/nixihz/capslock-bye/releases/latest/download/CapsLock-Bye-universal-notarized.dmg)
- [SHA-256 checksum](https://github.com/nixihz/capslock-bye/releases/latest/download/CapsLock-Bye-universal-notarized.dmg.sha256)

Download both files to the same directory to verify:

```sh
shasum -a 256 -c CapsLock-Bye-universal-notarized.dmg.sha256
```

## Local packaging

Store notarization credentials interactively, then build and notarize:

```sh
xcrun notarytool store-credentials caps-lock-bye-notary --team-id YOUR_TEAM_ID
./script/build_and_run.sh --release
./script/notarize.sh
```

Outputs are in `dist/release/`. Distribute the `-notarized.dmg`; `./script/build_dmg.sh` only packages and signs an existing Release app. Optional Task equivalents are `task release`, `task notarize`, and `task dmg`.

Use `CAPSBYE_SIGN_IDENTITY` to select a signing certificate, `CAPSBYE_NOTARY_PROFILE` for a different credential profile, or `CAPSBYE_NOTARY_KEYCHAIN` for a custom keychain.

## Retry a failure

- Locally, use `./script/notarize.sh --resume` after a timeout or network interruption. Do not rebuild the app or DMG between attempts; resume verifies their checksums.
- In Actions, inspect the failure and rerun the job. A fresh runner creates a new build and notarization submission. Available `notarization-*.json` diagnostics are retained as an artifact for seven days.
- Upload retries can update an existing draft release. Published assets are not overwritten; publish a new version instead.
