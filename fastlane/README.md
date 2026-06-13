fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

TestFlight 배포: 빌드번호 +1 → 아카이브 → 업로드(체인지로그 자동)

### ios release

```sh
[bundle exec] fastlane ios release
```

App Store 심사 제출: 빌드번호 +1 → 릴리즈노트 기록 → 아카이브 → 업로드(처리 대기) → 심사 제출

### ios bump_version

```sh
[bundle exec] fastlane ios bump_version
```

마케팅 버전 올리기 (사용법: fastlane bump_version type:patch|minor|major)

### ios status

```sh
[bundle exec] fastlane ios status
```

App Store 버전/상태 조회 (fastlane status)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
