import SwiftUI

/// 의존성 없는 미니 라인 차트 — Path 폴리라인 + 점.
/// 정렬(날짜 오름차순)·필터(값>0)는 호출부 책임이고, 라벨은 최소
/// (좌측 max/min 값, 하단 첫/끝 날짜)만 그린다.
struct FSLineChart: View {
    /// (날짜 "yyyy-MM-dd", 값) — 오름차순 정렬 상태로 넘길 것.
    let points: [(date: String, value: Double)]
    var unit: String = ""
    var height: CGFloat = 140
    @Environment(\.fsTheme) var t

    /// 위아래 여백 비율 — 선이 가장자리에 붙지 않게 한다.
    private static let pad: CGFloat = 0.1

    private var values: [Double] { points.map(\.value) }
    private var minValue: Double { values.min() ?? 0 }
    private var maxValue: Double { values.max() ?? 0 }

    /// "2026-06-08" -> "6.8"
    private func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return date }
        return "\(m).\(d)"
    }

    private func position(index: Int, value: Double, in size: CGSize) -> CGPoint {
        let x = points.count == 1
            ? size.width / 2
            : CGFloat(index) / CGFloat(points.count - 1) * size.width
        let span = maxValue - minValue
        let y: CGFloat
        if span == 0 {
            y = size.height / 2   // 모든 값이 같으면 중앙 수평선
        } else {
            let ratio = CGFloat((value - minValue) / span)
            y = size.height * (1 - Self.pad) - ratio * size.height * (1 - Self.pad * 2)
        }
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        if points.isEmpty {
            Text("측정 데이터가 없습니다")
                .font(.system(size: 12))
                .foregroundColor(t.textSec)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            HStack(alignment: .top, spacing: 8) {
                // y 라벨 (max / min)
                VStack(alignment: .trailing) {
                    Text(inbodyValue(maxValue, unit: unit))
                    Spacer()
                    Text(inbodyValue(minValue, unit: unit))
                }
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(t.textTer)
                .frame(height: height)

                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let coords = points.enumerated().map { i, p in
                            position(index: i, value: p.value, in: geo.size)
                        }
                        ZStack {
                            if coords.count > 1 {
                                Path { path in
                                    path.move(to: coords[0])
                                    for c in coords.dropFirst() {
                                        path.addLine(to: c)
                                    }
                                }
                                .stroke(t.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            }
                            ForEach(Array(coords.enumerated()), id: \.offset) { _, c in
                                Circle()
                                    .fill(t.accent)
                                    .frame(width: 7, height: 7)
                                    .overlay(Circle().stroke(t.bgElev, lineWidth: 1.5))
                                    .position(c)
                            }
                        }
                    }
                    .frame(height: height)

                    // x 라벨 (첫/끝 날짜)
                    HStack {
                        Text(shortDate(points[0].date))
                        Spacer()
                        if points.count > 1 {
                            Text(shortDate(points[points.count - 1].date))
                        }
                    }
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(t.textTer)
                }
            }
        }
    }
}
