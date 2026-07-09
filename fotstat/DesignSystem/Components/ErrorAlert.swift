import SwiftUI

extension View {
    /// errorMessage(Binding<String?>) 를 표준 오류 alert 로 표시한다. 여러 화면에 흩어져 있던
    /// `.alert(제목, isPresented: errorMessage != nil / clear) { 확인 } message: { Text }`
    /// 보일러플레이트를 한곳에 모은다. `enabled` 로 표시 조건을 추가로 게이트할 수 있다
    /// (예: 폼 시트가 열려 있을 때는 상위 화면 alert 를 숨김).
    func errorAlert(_ message: Binding<String?>, title: String = "오류", enabled: Bool = true) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { enabled && message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("확인", role: .cancel) { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
