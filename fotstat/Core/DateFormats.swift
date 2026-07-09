import Foundation

/// 앱 전역에서 재사용하는 날짜 포맷터. 로캘 영향을 받지 않도록 en_US_POSIX 로 고정해
/// 백엔드 형식("yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss")을 파싱·생성한다. DateFormatter 는
/// 생성 비용이 크므로 static 캐시로 공유한다.
enum DateFormats {
    /// 날짜만: "yyyy-MM-dd"
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// 날짜+시간: "yyyy-MM-dd HH:mm:ss" (백엔드 datetime)
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

extension Date {
    /// 오늘(로컬 캘린더)을 "yyyy-MM-dd" 문자열로.
    static var todayYMD: String { DateFormats.day.string(from: Date()) }
}

extension StringProtocol {
    /// 날짜/일시 문자열의 앞 10자("yyyy-MM-dd"). 형식이 고정폭이라 문자열 비교에 안전.
    var dayPrefix: String { String(prefix(10)) }
}
