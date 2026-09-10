# Contributing

Issues and pull requests in English or Simplified Chinese are welcome. Use the [bug report template](https://github.com/nixihz/capslock-bye/issues/new?template=bug_report.md) to describe a problem, without including passwords or private input.

## Develop

Follow the [build instructions](README.md#build-from-source). If your Mac uses standalone Command Line Tools, select the full Xcode installation first:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Useful commands:

```sh
swift test                              # State machine and keyboard event tests
./script/build_and_run.sh --build-only  # Build without launching
./script/build_and_run.sh --ci          # Build a universal, ad-hoc signed ZIP
./script/build_and_run.sh --debug       # Launch under LLDB
./script/build_and_run.sh --logs        # Launch and stream process logs
```

[Task](https://taskfile.dev/) is optional: `task build`, `task test`, and `task ci` wrap the same commands. Set `CAPSBYE_SIGN_IDENTITY` to a certificate's name or SHA-1 to select it, or `-` for ad-hoc signing.

## Check your change

Run `swift test` and `./script/build_and_run.sh --ci` before opening a pull request. CI runs both commands; its development artifacts are not notarized. Keyboard event tests use a replacement output sink and do not send keystrokes to your desktop.

For input changes, also check with a physical keyboard:

- Taps emit exactly one key; holds and chords release without an extra tap.
- Pause, quit, sleep, and keyboard disconnect release simulated modifiers while preserving physical modifiers the user still holds.
- Settings persist across relaunch; permission revocation and reauthorization work.
- Secure Input pauses mapping and normal behavior resumes afterward.

State which hardware and macOS versions you tested. Synthetic Caps Lock events cannot replace physical HID testing, and a universal build alone does not verify Intel or macOS 14 behavior.

## Submit

Keep changes focused, explain their effect, and include validation results. Update both [English](README.md) and [Chinese](docs/README.zh-CN.md) documentation when behavior changes, and keep UI strings bilingual.

Keep generated builds and signing material out of Git. Maintainers can use the [release guide](docs/releasing.md) to publish downloads.
