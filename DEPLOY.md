# iOS 배포 자동화 (fastlane)

빌드번호 자동 증가 + git 커밋 기반 체인지로그 + App Store Connect API 키 인증.

## 1. 최초 1회 설정

### fastlane 설치 (Homebrew 권장 — 자체 Ruby 번들)

```bash
brew install fastlane
```

> 시스템 Ruby(2.6.10)는 구버전이라 `gem install` 대신 Homebrew 설치를 권장.
> bundler를 쓰려면 rbenv 등으로 Ruby 3.x 설치 후 `bundle install`.

### App Store Connect API 키 발급

1. App Store Connect → **사용자 및 액세스 → 통합(Integrations) → App Store Connect API**
2. 팀 키 생성(역할: App Manager 이상) → `AuthKey_XXXXXX.p8` 다운로드 (재다운로드 불가, 안전히 보관)
3. **Key ID**, **Issuer ID** 메모

### 환경변수 설정

```bash
cp fastlane/.env.default fastlane/.env
```

`fastlane/.env` 를 열어 채운다:

```
ASC_KEY_ID=XXXXXXXXXX
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_KEY_FILEPATH=./fastlane/AuthKey.p8
```

다운로드한 `.p8` 를 `ASC_KEY_FILEPATH` 경로(예: `fastlane/AuthKey.p8`)에 둔다.
`.env` 와 `*.p8` 는 `.gitignore` 로 커밋 제외됨.

## 2. 사용법

```bash
# TestFlight 배포 (빌드번호 +1, 체인지로그 자동, 외부 테스터 미배포)
fastlane beta

# App Store 심사 제출 (릴리즈노트 자동 기록 + 승인 후 자동 출시)
fastlane release

# 마케팅 버전 올리기 (예: 1.0 → 1.0.1 / 1.1.0 / 2.0.0)
fastlane bump_version type:patch
fastlane bump_version type:minor
fastlane bump_version type:major
```

## 3. 동작 방식

- **빌드번호**: TestFlight·App Store 최신 빌드번호의 +1 로 자동 설정 (중복 거부 방지). `set_info_plist_value`로 Info.plist의 `CFBundleVersion`에 직접 기록 (agvtool 미사용)
- **release 업로드 흐름**: 바이너리 업로드 후 App Store Connect의 **처리(Processing)가 끝날 때까지 대기**(수 분 소요)한 뒤 빌드를 버전에 연결해 심사 제출. 처리 전 연결 시 실패하기 때문
- **마케팅 버전**: 승인/마감된 버전(예: 1.0)으로는 새 빌드를 올릴 수 없음. 새 릴리즈 사이클 시작 시 `bump_version`으로 먼저 올릴 것
- **체인지로그**: 마지막 git 태그 이후의 커밋 메시지(`- 메시지` 형식, merge 제외)를 모아 생성
  - `beta` → TestFlight "테스트 정보"의 What to Test
  - `release` → `fastlane/metadata/<로케일>/release_notes.txt` 에 기록되어 App Store 릴리즈노트로 업로드
- **버전 커밋/태그**: 배포 성공 후 `chore(release): <버전> (<빌드>)` 커밋 + `v<버전>-<빌드>` 태그 생성
  - 기본은 로컬만. 원격 푸시하려면 `PUSH_AFTER_DEPLOY=1 fastlane release`

## 4. 참고

- 코드 서명은 자동 서명(Automatic, 팀 `M4VAR7JKUT`)을 사용. Xcode에 Apple 계정이 로그인돼 있어야 로컬 아카이브 가능.
- 여러 머신/CI에서 서명을 공유하려면 추후 `match` 도입 고려.
- 마케팅 버전(`MARKETING_VERSION`)은 수동 관리 — `bump_version` 으로 올리거나 Xcode에서 변경.
