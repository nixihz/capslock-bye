# Releasing

GitHub Actions builds CapsLock Bye and publishes signed, notarized DMGs to [GitHub Releases](https://github.com/nixihz/capslock-bye/releases).

## Configure once

In **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded `.p12` containing a Developer ID Application certificate and its private key |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Non-empty password protecting the `.p12` |
| `APPLE_API_KEY_P8_BASE64` | Base64-encoded App Store Connect team API `.p8` key |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API issuer ID |

Export the certificate and private key from Keychain Access. Copy the encoded file with `base64 -i /path/to/DeveloperID.p12 | pbcopy`, then paste it into the secret. Keep the certificate outside the repository.

These are the same five secret names used by [JoyHarness](https://github.com/nixihz/JoyHarness). You can reuse its certificate and API key for the same Apple developer team, but repository secrets must be configured separately: GitHub cannot read back their values or copy them between repositories.

To upload files directly without displaying the private keys, run:

```sh
base64 -i /path/to/DeveloperID.p12 | gh secret set DEVELOPER_ID_CERTIFICATE_BASE64 --repo nixihz/capslock-bye
gh secret set DEVELOPER_ID_CERTIFICATE_PASSWORD --repo nixihz/capslock-bye
base64 -i /path/to/AuthKey_XXXXXXXXXX.p8 | gh secret set APPLE_API_KEY_P8_BASE64 --repo nixihz/capslock-bye
gh secret set APPLE_API_KEY_ID --repo nixihz/capslock-bye
gh secret set APPLE_API_ISSUER_ID --repo nixihz/capslock-bye
```

Commands without piped input prompt for the value. All five secrets are required for a release. The workflow imports them into a temporary keychain, validates the credentials, and removes the keychain and decoded files when it finishes.

CI needs no secrets. Releases use GitHub's built-in token, so no personal access token is required. Both workflows use `macos-26` with Xcode 26.6; update their `DEVELOPER_DIR` values together when upgrading.

## Build on GitHub

Pushes to `main` and pull requests run tests and build a universal app. For a manual build, open **Actions → CI → Run workflow**, or run:

```sh
gh workflow run ci.yml --repo nixihz/capslock-bye --ref main
```

Download `CapsLock-Bye-ci-<commit>` from the completed run's **Artifacts** section. It contains an ad-hoc signed ZIP and SHA-256 checksum for Apple Silicon and Intel. This development build is not notarized.

## Publish

1. Update `CFBundleShortVersionString` in `Resources/Info.plist` and increment `CFBundleVersion`.
2. Commit and push to `main`, then wait for CI to pass.
3. Open **Actions → Release → Run workflow**, select `main`, and enter the matching version, for example `1.0.0`. The equivalent CLI command is:

   ```sh
   gh workflow run release.yml --repo nixihz/capslock-bye --ref main -f version=1.0.0
   ```

   The workflow creates the version tag at the checked-out commit when preparing the release. Alternatively, push a matching version tag to trigger the same workflow:

   ```sh
   git tag -a v1.0.0 -m "CapsLock Bye 1.0.0"
   git push origin v1.0.0
   ```

The release workflow tests, builds both architectures, signs, notarizes, and verifies the DMG. It uploads all assets to a draft release before making it public. Versions must match the plist and use `<major>.<minor>.<patch>` (an optional `v` prefix is accepted for manual requests). Manual releases must run from `main`; an existing version tag must point to the checked-out commit. Release jobs run one at a time, including tag and manual triggers. Forks must update the workflow's repository check to publish their own releases.

Publish only the versioned DMG and its matching SHA-256 checksum:

- `CapsLock-Bye-<version>-universal-notarized.dmg`
- `CapsLock-Bye-<version>-universal-notarized.dmg.sha256`

The website and READMEs link to the [latest release page](https://github.com/nixihz/capslock-bye/releases/latest), where users select the versioned installer. Do not upload a second copy with an unversioned filename.

Download both files to the same directory to verify, replacing `1.0.0` with the downloaded version:

```sh
shasum -a 256 -c CapsLock-Bye-1.0.0-universal-notarized.dmg.sha256
```

## Local packaging

Store notarization credentials interactively, then build and notarize:

```sh
xcrun notarytool store-credentials caps-lock-bye-notary \
  --key /path/to/AuthKey_XXXXXXXXXX.p8 --key-id YOUR_KEY_ID --issuer YOUR_ISSUER_ID
./script/build_and_run.sh --release
./script/notarize.sh
```

An existing Apple Account profile also works locally. To create one, use `xcrun notarytool store-credentials caps-lock-bye-notary --team-id YOUR_TEAM_ID` and follow its prompts.

Outputs are in `dist/release/`. Distribute the `-notarized.dmg`; `./script/build_dmg.sh` only packages and signs an existing Release app. Optional Task equivalents are `task release`, `task notarize`, and `task dmg`.

Use `CAPSBYE_SIGN_IDENTITY` to select a signing certificate, `CAPSBYE_NOTARY_PROFILE` for a different credential profile, or `CAPSBYE_NOTARY_KEYCHAIN` for a custom keychain.

## Retry a failure

- Locally, use `./script/notarize.sh --resume` after a timeout or network interruption. Do not rebuild the app or DMG between attempts; resume verifies their checksums.
- In Actions, inspect the failure and rerun the job. A fresh runner creates a new build and notarization submission. Available `notarization-*.json` diagnostics are retained as an artifact for seven days.
- Upload retries can update an existing draft release. Published assets are not overwritten; publish a new version instead.
