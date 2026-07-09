import Foundation
import Combine

/// CRUD ViewModel 이 공유하는 네트워킹 보일러플레이트(로딩 토글·에러 캡처·삭제 중복 방지)를
/// 담는 베이스. 각 ViewModel 은 이를 상속하고 도메인 상태(@Published 목록 등)만 더한 뒤
/// withLoading / run / withDeleting 안에 실제 요청 body 만 넣는다.
@MainActor
class LoadableViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// 진행 중인 삭제 id — 뷰가 삭제 버튼 비활성 등에 관찰한다.
    @Published var deletingIds: Set<Int> = []

    /// 로딩 표시가 필요한 조회용: isLoading 토글 + errorMessage 초기화 + 에러 캡처.
    func withLoading(_ body: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { try await body() } catch { errorMessage = error.localizedDescription }
    }

    /// mutate 후 refetch 등: 로딩 표시 없이 실행하고 실패만 errorMessage 로.
    /// 조회처럼 errorMessage 를 미리 지우지 않아 기존 create/update 동작과 동일하다.
    func mutate(_ body: () async throws -> Void) async {
        do { try await body() } catch { errorMessage = error.localizedDescription }
    }

    /// 같은 id 중복 삭제를 막고 진행 중 id 를 deletingIds 로 표시한 뒤 body 실행 + 에러 캡처.
    func withDeleting(_ id: Int, _ body: () async throws -> Void) async {
        guard !deletingIds.contains(id) else { return }
        deletingIds.insert(id)
        defer { deletingIds.remove(id) }
        do { try await body() } catch { errorMessage = error.localizedDescription }
    }
}
