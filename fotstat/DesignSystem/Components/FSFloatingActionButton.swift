import SwiftUI

/// 우하단 원형 + 버튼(FAB). 부모 ZStack 위에 올려 화면 오른쪽 아래에 고정한다.
/// accent 원형 위 plus 아이콘 + 그림자. 리스트 화면들의 "추가" 액션 공통.
struct FSFloatingActionButton: View {
    @Environment(\.fsTheme) private var t
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(t.accent)
                        .clipShape(Circle())
                        .shadow(color: t.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
            }
        }
    }
}
