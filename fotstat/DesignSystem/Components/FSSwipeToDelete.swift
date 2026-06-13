import SwiftUI

/// 좌로 슬라이드하면 우측에 삭제 버튼이 드러나는 래퍼.
/// `List`의 `.swipeActions`를 쓸 수 없는 커스텀 카드 레이아웃에서 사용한다.
///
/// `id`/`openID`를 함께 넘기면 한 번에 하나의 패널만 열린 상태를 유지한다
/// (다른 row를 스와이프하면 기존에 열린 패널은 자동으로 닫힘).
struct FSSwipeToDelete<Content: View, ID: Hashable>: View {
    let id: ID
    @Binding var openID: ID?
    @ViewBuilder var content: () -> Content
    var onDelete: () -> Void

    @Environment(\.fsTheme) var t
    @State private var offset: CGFloat = 0

    private let revealWidth: CGFloat = 76

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
        if openID == id { openID = nil }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                close()
                onDelete()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                    Text("삭제")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: revealWidth)
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }
            .buttonStyle(.plain)
            // 스와이프하지 않은 상태에서는 카드 둥근 모서리로 빨간색이 비치지 않도록 숨김
            .opacity(offset < 0 ? 1 : 0)

            content()
                .background(t.bgElev)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 16)
                        .onChanged { value in
                            // 수평 이동이 수직보다 우세할 때만 반응 (스크롤과 공존)
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let base = value.translation.width
                            if base < 0 {
                                offset = max(base, -revealWidth)
                                openID = id  // 열기 시작하면 다른 패널은 닫히도록 알림
                            } else {
                                offset = min(0, -revealWidth + base)
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -revealWidth / 2 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = -revealWidth }
                                openID = id
                            } else {
                                close()
                            }
                        }
                )
        }
        .clipped()
        // 다른 row가 열리면 이 패널은 닫는다.
        .onChange(of: openID) { _, newValue in
            if newValue != id && offset != 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
            }
        }
    }
}
