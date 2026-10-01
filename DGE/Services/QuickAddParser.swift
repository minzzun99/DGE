import Foundation

/// 한 줄 입력에서 읽어낸 할 일.
struct ParsedTask: Equatable {
    var title: String
    var dueDate: Date?
    /// 시각을 말했으면 그 시각에 알림을 건다.
    var remindAt: Date?
    var tags: [String] = []
    var priority: Priority = .none
    var listName: String?
    var repeatRule: RepeatRule?

    /// 제목 말고 알아들은 것이 있는지. (미리보기를 띄울지 정할 때)
    var hasHints: Bool {
        dueDate != nil || remindAt != nil || !tags.isEmpty || priority != .none
            || listName != nil || repeatRule != nil
    }
}

/// "내일 오후 3시 보고서 제출 #업무 !!" 같은 입력을 할 일로 바꾼다.
///
/// 띄어쓰기로 나뉜 낱말 하나(또는 둘)가 통째로 맞을 때만 알아듣는다.
/// "오늘의 회고"의 "오늘의"처럼 붙어 있는 말은 제목으로 남는다.
enum QuickAddParser {
    static func parse(
        _ input: String,
        listNames: [String] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ParsedTask {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var words = merged(trimmed.split(separator: " ").map(String.init))
        var result = ParsedTask(title: trimmed)
        var kept: [String] = []
        var time: DateComponents?
        let today = calendar.startOfDay(for: now)

        var index = 0
        while index < words.count {
            let word = words[index]
            let next = index + 1 < words.count ? words[index + 1] : nil

            // 두 낱말짜리를 먼저 본다. ("다음주 금요일", "10월 3일", "오후 3시", "3일 뒤")
            if let next {
                if result.dueDate == nil, let date = twoWordDate(word, next, today: today, calendar: calendar) {
                    result.dueDate = date
                    index += 2
                    continue
                }
                if time == nil, let parsed = twoWordTime(word, next) {
                    time = parsed
                    index += 2
                    index += consumeMinutes(after: index, in: words, into: &time)
                    continue
                }
            }

            if result.dueDate == nil, let date = oneWordDate(word, today: today, calendar: calendar) {
                result.dueDate = date
            } else if time == nil, let parsed = oneWordTime(word) {
                time = parsed
                index += consumeMinutes(after: index + 1, in: words, into: &time)
            } else if result.repeatRule == nil, let rule = repeatRule(word) {
                result.repeatRule = rule
            } else if result.priority == .none, let priority = priority(word) {
                result.priority = priority
            } else if let tag = tag(word) {
                if !result.tags.contains(tag) { result.tags.append(tag) }
            } else if result.listName == nil, let list = list(word, in: listNames) {
                result.listName = list
            } else {
                kept.append(word)
            }
            index += 1
        }
        words = kept

        // 반복만 말하고 날짜가 없으면 오늘부터 시작한다.
        if result.repeatRule != nil, result.dueDate == nil {
            result.dueDate = today
        }

        if let time {
            var base = result.dueDate ?? today
            var remind = calendar.date(
                bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: base
            ) ?? base
            // 날짜 없이 시각만 말했는데 이미 지났다면 내일 그 시각.
            if result.dueDate == nil, remind <= now {
                base = calendar.date(byAdding: .day, value: 1, to: base) ?? base
                remind = calendar.date(byAdding: .day, value: 1, to: remind) ?? remind
            }
            result.dueDate = calendar.startOfDay(for: base)
            result.remindAt = remind
        }

        // 전부 인식어였다면 원래 문장을 그대로 제목으로 쓴다. ("내일"이라는 할 일일 수도 있다)
        let title = words.joined(separator: " ")
        if title.isEmpty {
            return ParsedTask(title: trimmed)
        }
        result.title = title
        return result
    }

    // MARK: - 날짜

    private static let weekdays = ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"]

    /// "다음 주"처럼 띄어 쓴 말을 한 낱말로 붙인다.
    private static func merged(_ words: [String]) -> [String] {
        var result: [String] = []
        var index = 0
        while index < words.count {
            if index + 1 < words.count, ["다음", "이번"].contains(words[index]), words[index + 1] == "주" {
                result.append(words[index] + "주")
                index += 2
            } else {
                result.append(words[index])
                index += 1
            }
        }
        return result
    }

    private static func oneWordDate(_ word: String, today: Date, calendar: Calendar) -> Date? {
        func days(_ value: Int) -> Date? { calendar.date(byAdding: .day, value: value, to: today) }

        switch word {
        case "오늘": return today
        case "내일": return days(1)
        case "모레": return days(2)
        case "글피": return days(3)
        case "다음주": return nextWeek(from: today, calendar: calendar)
        case "주말", "이번주말": return upcoming(weekday: 7, from: today, calendar: calendar)
        default: break
        }

        if let weekday = weekdays.firstIndex(of: word) {
            return upcoming(weekday: weekday + 1, from: today, calendar: calendar)
        }

        // "3일후", "2주뒤"
        if let match = word.wholeMatch(of: #/(\d{1,3})(일|주)(후|뒤)/#) {
            guard let count = Int(match.1) else { return nil }
            return days(match.2 == "일" ? count : count * 7)
        }

        // "9/30", "9.30", "10월3일"
        if let match = word.wholeMatch(of: #/(\d{1,2})[/.](\d{1,2})\.?/#) {
            return monthDay(Int(match.1), Int(match.2), today: today, calendar: calendar)
        }
        if let match = word.wholeMatch(of: #/(\d{1,2})월(\d{1,2})일/#) {
            return monthDay(Int(match.1), Int(match.2), today: today, calendar: calendar)
        }
        return nil
    }

    private static func twoWordDate(_ first: String, _ second: String, today: Date, calendar: Calendar) -> Date? {
        // "다음주 금요일"
        if first == "다음주", let weekday = weekdays.firstIndex(of: second) {
            let monday = nextWeek(from: today, calendar: calendar)
            // 월요일이 0이 되도록 맞춘다.
            let offset = (weekday + 6) % 7
            return calendar.date(byAdding: .day, value: offset, to: monday)
        }
        // "이번주 금요일"
        if first == "이번주", let weekday = weekdays.firstIndex(of: second) {
            return upcoming(weekday: weekday + 1, from: today, calendar: calendar)
        }
        // "10월 3일"
        if let month = first.wholeMatch(of: #/(\d{1,2})월/#), let day = second.wholeMatch(of: #/(\d{1,2})일/#) {
            return monthDay(Int(month.1), Int(day.1), today: today, calendar: calendar)
        }
        // "3일 후", "2주 뒤"
        if let count = first.wholeMatch(of: #/(\d{1,3})(일|주)/#), ["후", "뒤"].contains(second) {
            guard let value = Int(count.1) else { return nil }
            return calendar.date(byAdding: .day, value: count.2 == "일" ? value : value * 7, to: today)
        }
        return nil
    }

    /// 오늘을 포함해 가장 가까운 그 요일. (1 = 일요일)
    private static func upcoming(weekday: Int, from today: Date, calendar: Calendar) -> Date {
        let current = calendar.component(.weekday, from: today)
        let offset = (weekday - current + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    /// 다음 주 월요일.
    private static func nextWeek(from today: Date, calendar: Calendar) -> Date {
        calendar.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) ?? today
    }

    /// 올해 그날이 이미 지났으면 내년으로 본다.
    private static func monthDay(_ month: Int?, _ day: Int?, today: Date, calendar: Calendar) -> Date? {
        guard let month, let day, (1...12).contains(month), (1...31).contains(day) else { return nil }
        let year = calendar.component(.year, from: today)
        var components = DateComponents(year: year, month: month, day: day)
        guard var date = calendar.date(from: components),
              calendar.component(.day, from: date) == day else { return nil }
        if date < today {
            components.year = year + 1
            date = calendar.date(from: components) ?? date
        }
        return date
    }

    // MARK: - 시각

    private static func oneWordTime(_ word: String) -> DateComponents? {
        // "14:30"
        if let match = word.wholeMatch(of: #/(\d{1,2}):(\d{2})/#) {
            return components(Int(match.1), Int(match.2), afternoon: nil)
        }
        // "오후3시", "오전9시30분", "3시", "3시반"
        if let match = word.wholeMatch(of: #/(오전|오후)?(\d{1,2})시(?:(\d{1,2})분|(반))?/#) {
            let minute = match.4 != nil ? 30 : Int(match.3 ?? "0")
            return components(Int(match.2), minute, afternoon: match.1.map { $0 == "오후" })
        }
        return nil
    }

    /// "9시 30분"처럼 분을 따로 띄어 쓴 경우. 먹은 낱말 수를 돌려준다.
    private static func consumeMinutes(after index: Int, in words: [String], into time: inout DateComponents?) -> Int {
        guard index < words.count, time?.minute == 0 else { return 0 }
        if words[index] == "반" {
            time?.minute = 30
            return 1
        }
        if let match = words[index].wholeMatch(of: #/(\d{1,2})분/#), let minute = Int(match.1), (0...59).contains(minute) {
            time?.minute = minute
            return 1
        }
        return 0
    }

    private static func twoWordTime(_ first: String, _ second: String) -> DateComponents? {
        guard first == "오전" || first == "오후" else { return nil }
        guard let match = second.wholeMatch(of: #/(\d{1,2})시(?:(\d{1,2})분|(반))?/#) else { return nil }
        let minute = match.3 != nil ? 30 : Int(match.2 ?? "0")
        return components(Int(match.1), minute, afternoon: first == "오후")
    }

    private static func components(_ hour: Int?, _ minute: Int?, afternoon: Bool?) -> DateComponents? {
        guard var hour, let minute, (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        if afternoon == true, hour < 12 { hour += 12 }
        if afternoon == false, hour == 12 { hour = 0 }
        // "3시"처럼 오전/오후 없이 작은 숫자면 일하는 시간대(오후)로 본다.
        if afternoon == nil, (1...6).contains(hour) { hour += 12 }
        return DateComponents(hour: hour, minute: minute)
    }

    // MARK: - 나머지

    private static func repeatRule(_ word: String) -> RepeatRule? {
        switch word {
        case "매일": .daily
        case "평일", "평일마다": .weekdays
        case "매주": .weekly
        case "격주": .biweekly
        case "매월", "매달": .monthly
        case "매년": .yearly
        default: nil
        }
    }

    private static func priority(_ word: String) -> Priority? {
        switch word {
        case "!", "!낮음": .low
        case "!!", "!보통": .medium
        case "!!!", "!높음", "!중요", "!급함": .high
        default: nil
        }
    }

    /// "#업무" → "업무". 숫자만 있으면("#128") 이슈 번호일 수 있으니 태그로 보지 않는다.
    private static func tag(_ word: String) -> String? {
        guard word.hasPrefix("#") else { return nil }
        let name = String(word.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ",.;:"))
        guard !name.isEmpty, name.contains(where: \.isLetter) else { return nil }
        return name
    }

    /// "@공부" → 이미 있는 목록 이름일 때만.
    private static func list(_ word: String, in names: [String]) -> String? {
        guard word.hasPrefix("@"), word.count > 1 else { return nil }
        let name = String(word.dropFirst())
        return names.first { $0.compare(name, options: [.caseInsensitive]) == .orderedSame }
    }
}
