import SwiftUI

extension View {
    /// 파괴적 삭제 확인 다이얼로그. `item` 이 non-nil 이면 표시하고, "삭제" 탭 시 `onDelete` 실행.
    /// 리스트 화면들의 팀·선수·경기 삭제 확인 보일러플레이트를 한곳에 모은다.
    func deleteConfirmation<Item>(
        _ title: String,
        item: Binding<Item?>,
        message: @escaping (Item) -> String,
        onDelete: @escaping (Item) -> Void
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: item.wrappedValue
        ) { presented in
            Button("삭제", role: .destructive) { onDelete(presented) }
            Button("취소", role: .cancel) {}
        } message: { presented in
            Text(message(presented))
        }
    }
}
