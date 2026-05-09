<div align="center">

# ⚽ Fotstat — iOS App

**SwiftUI 기반 축구 경기 통계 및 기록 관리 앱**

[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS%2026-007AFF?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Xcode](https://img.shields.io/badge/Xcode-16+-147EFB?style=flat-square&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)

</div>

---

## 개요

팀 관리부터 선수 기록, 경기 결과, 통계까지 — 축구 팀의 모든 데이터를 한 앱에서 관리합니다.
iOS 26 Liquid Glass 디자인 언어를 적용한 네이티브 SwiftUI 앱입니다.

---

## 기술 스택

| 구분 | 기술 |
|---|---|
| 언어 | Swift 6 |
| UI 프레임워크 | SwiftUI |
| 최소 OS | iOS 26 |
| 아키텍처 | MVVM |
| 네트워크 | URLSession + async/await |
| 상태관리 | ObservableObject / @Published |
| 인증 | JWT Bearer Token (UserDefaults 저장) |

---

## 주요 기능

| 기능 | 설명 |
|---|---|
| **팀 관리** | 팀 생성, 홈 대시보드, 최근 경기 W/D/L 배지, 경기 캘린더 |
| **선수단** | 포지션별 그룹(GK/DF/MF/FW), 선수 추가/수정, 시즌 통계 표시 |
| **경기** | 경기 등록, 쿼터 추가, 원정 골 수 수정, 예정/완료 분류 |
| **기록 입력** | 선수별 골/어시스트/출전시간 실시간 입력 및 수정 |
| **통계** | 날짜 범위 필터, 득점/어시스트/출전시간 순위, 승률, 선수 상세 비교 |
| **설정** | 다크/라이트/시스템 테마 전환, 프로필 확인, 로그아웃 |

---

## 프로젝트 구조

```
fotstat_ios/
├── App/
│   ├── fotstatApp.swift         # 앱 진입점, RootView, 테마 설정
│   └── MainTabView.swift
├── Core/
│   ├── Auth/
│   │   └── AuthManager.swift    # JWT 토큰 저장 및 로그인 상태 관리
│   └── Network/
│       ├── APIClient.swift      # URLSession 기반 공통 네트워크 클라이언트
│       ├── Endpoint.swift       # API 엔드포인트 정의
│       ├── Config.swift         # 서버 주소 설정 (gitignore — 직접 생성 필요)
│       ├── Config.example.swift # Config.swift 템플릿
│       └── Models/
│           └── AppModels.swift  # 공통 데이터 모델 (User, Team, Player 등)
├── DesignSystem/
│   ├── Theme.swift              # FSTheme (색상, 타이포그래피 토큰)
│   ├── ColorAssets.swift
│   └── Components/
│       ├── FSGlassButton.swift  # iOS 26 Liquid Glass 버튼
│       ├── FSCrest.swift        # 팀 크레스트 (이니셜 기반)
│       ├── FSResultPill.swift   # W/D/L 결과 뱃지
│       ├── FSStatTile.swift     # 통계 타일 카드
│       ├── DateRangeFilter.swift# 날짜 범위 필터 컴포넌트
│       ├── FSPlayerAvatar.swift
│       ├── FSPosChip.swift      # 포지션 칩 (GK/DF/MF/FW/ST...)
│       ├── FSSectionHeader.swift
│       ├── FSStepper.swift
│       └── FSTabBar.swift       # 커스텀 글래스 탭바
└── Features/
    ├── Auth/                    # 로그인 / 회원가입
    ├── Team/                    # 팀 목록, 팀 홈, 캘린더
    ├── Player/                  # 선수단 목록, 추가/수정 폼
    ├── Match/                   # 경기 목록, 상세, 쿼터 관리
    ├── Record/                  # 선수별 기록 입력
    ├── Stats/                   # 통계, 선수 상세 비교
    └── Settings/                # 테마, 프로필, 로그아웃
```

---

## 시작하기

### 요구사항

- Xcode 16+
- iOS 26 SDK
- 실행 중인 [fotstat API 서버](../fotstat_go)

### 1. Config.swift 생성

서버 주소가 포함된 `Config.swift`는 보안상 gitignore 처리되어 있습니다. 직접 생성해야 합니다.

```bash
cp Core/Network/Config.example.swift Core/Network/Config.swift
```

`Config.swift`를 열어 서버 주소를 수정합니다:

```swift
enum Config {
    static let baseURL = "http://YOUR_SERVER_IP:8007/api"
}
```

로컬 서버를 사용하는 경우 `Info.plist`의 `NSExceptionDomains`에 해당 IP를 추가해야 HTTP 통신이 허용됩니다:

```xml
<key>NSExceptionDomains</key>
<dict>
    <key>YOUR_SERVER_IP</key>
    <dict>
        <key>NSExceptionAllowsInsecureHTTPLoads</key>
        <true/>
    </dict>
</dict>
```

### 2. Xcode에서 실행

```
fotstat.xcodeproj 를 열고 시뮬레이터 또는 실기기에서 실행
```

---

## 아키텍처

### MVVM

```
View (SwiftUI)
  └── ViewModel (@MainActor, ObservableObject)
        └── APIClient (async/await)
              └── Endpoint → URLRequest
```

- **View**: SwiftUI 선언형 UI, `@Environment(\.fsTheme)`으로 테마 주입
- **ViewModel**: `@Published` 프로퍼티로 상태 관리, `async/await` 비동기 처리
- **APIClient**: 싱글톤, JWT 토큰 자동 첨부, 공통 에러 처리

### 테마 시스템

`FSTheme`이 `EnvironmentKey`로 주입되어 다크/라이트 모드를 일관되게 처리합니다.

```swift
@Environment(\.fsTheme) var t

Text("Hello").foregroundColor(t.text)
```

`@AppStorage("themePreference")`로 시스템/라이트/다크 선택을 영구 저장합니다.

### 네비게이션

iOS 16+ `NavigationStack` + `NavigationLink(value:)` + `navigationDestination(for:)` 패턴을 사용합니다.

---

## 화면 구성

```
HomeView (팀 목록)
└── TeamContextView (TabView)
    ├── 홈 탭 — 대시보드, 최근 경기, 캘린더
    ├── 선수단 탭 — 포지션별 선수 목록 + 시즌 통계
    ├── 경기 탭 — 예정/완료 경기 목록
    │   └── MatchDetailView — 쿼터 스코어 + 원정 골 수정
    │       └── RecordView — 선수별 기록 입력
    └── 통계 탭 — 날짜 필터 + 순위 + 선수 상세
```

---

## 보안

- 서버 주소(`Config.swift`)는 `.gitignore`에 포함되어 커밋되지 않습니다
- JWT 토큰은 `UserDefaults`에 저장됩니다
- `Info.plist`의 `NSExceptionDomains`에는 `localhost`만 기본 허용되어 있습니다
