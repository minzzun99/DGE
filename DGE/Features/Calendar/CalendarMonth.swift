import Foundation

/// 한 달을 주 단위 격자로 나눠주는 계산기. 뷰는 이 결과만 그린다.
struct CalendarMonth {
    /// 표시 중인 달 안의 아무 날짜.
    let reference: Date

    private var calendar: Calendar { Calendar.dge }

    /// "2026년 9월"
    var title: String {
        reference.formatted(.dateTime.year().month(.wide))
    }

    var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: reference)) ?? reference
    }

    /// 일요일부터 시작하는 지역이면 ["일", "월", ...] 순으로 돌려준다.
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    /// 실제로 필요한 주만 담는다. (빈 줄이 남지 않게)
    var weeks: [[Date]] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else { return [] }

        let totalCells = Int((Double(leading + range.count) / 7).rounded(.up)) * 7

        return stride(from: 0, to: totalCells, by: 7).map { weekOffset in
            (0..<7).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: weekOffset + dayOffset, to: gridStart)
            }
        }
    }

    func isInDisplayedMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
    }

    func adding(months: Int) -> CalendarMonth {
        CalendarMonth(reference: calendar.date(byAdding: .month, value: months, to: reference) ?? reference)
    }

    static var current: CalendarMonth {
        CalendarMonth(reference: Date())
    }
}
