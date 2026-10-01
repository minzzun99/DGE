import Foundation

extension Date {
    static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    static var startOfTomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
    }

    /// 다음 주 월요일. 오늘이 월요일이어도 일주일 뒤를 준다.
    static var startOfNextWeek: Date {
        Calendar.current.nextDate(
            after: startOfToday,
            matching: DateComponents(weekday: 2),
            matchingPolicy: .nextTime
        ) ?? startOfTomorrow
    }

    /// "9월 21일 월요일"
    var dgeHeaderText: String {
        formatted(.dateTime.month(.wide).day().weekday(.wide))
    }

    /// 목록에서 곁들여 보여주는 짧은 날짜.
    var dgeShortText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "오늘" }
        if calendar.isDateInTomorrow(self) { return "내일" }
        if calendar.isDateInYesterday(self) { return "어제" }
        return formatted(.dateTime.month(.defaultDigits).day())
    }

    /// 묶음 제목에 쓰는 날짜. "오늘", "내일", "어제", "9월 25일 목요일"
    var dgeDayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "오늘" }
        if calendar.isDateInTomorrow(self) { return "내일" }
        if calendar.isDateInYesterday(self) { return "어제" }
        return dgeHeaderText
    }

    /// "오후 2:30"
    var dgeTimeText: String {
        formatted(date: .omitted, time: .shortened)
    }
}
