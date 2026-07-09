import Foundation

/// 홈/원정 득점으로 결정되는 경기 결과(승/무/패). W/D/L 코드와 한글 라벨 매핑의 단일 원천 —
/// MatchScore·PlayerMatchLog·팀 전적 집계가 공유한다.
enum MatchOutcome {
    case win, draw, loss

    init(home: Int, away: Int) {
        self = home > away ? .win : (home < away ? .loss : .draw)
    }

    /// "W" / "D" / "L"
    var code: String {
        switch self {
        case .win: return "W"
        case .draw: return "D"
        case .loss: return "L"
        }
    }

    /// "승" / "무" / "패"
    var label: String {
        switch self {
        case .win: return "승"
        case .draw: return "무"
        case .loss: return "패"
        }
    }
}
