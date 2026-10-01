import SwiftUI
import SwiftData

/// 캘린더 본문. 일 · 주 · 월 보기를 오가며 일정과 날짜가 정해진 할 일을 함께 보여준다.
/// 칩을 누르면 고르고, 다른 날짜(주 · 일 보기에서는 다른 시각)로 끌어 옮긴다.
struct CalendarBoard: View {
    /// 지금 보고 있는 날. 월 보기면 그 달, 주 보기면 그 주.
    @Binding var anchor: Date
    let onSelectEvent: (CalendarEvent) -> Void
    let onSelectTask: (TodoTask) -> Void
    let onSelectExternal: (ExternalEvent) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]
    @Query(sort: \TodoTask.order) private var tasks: [TodoTask]
    @AppStorage(SettingsKey.calendarMode) private var modeRaw = CalendarMode.month.rawValue
    /// 할 일도 캘린더에 보여줄지. 기본은 켜둔다.
    @AppStorage(SettingsKey.calendarShowsTasks) private var showsTasks = true
    @AppStorage(SettingsKey.showSystemCalendars) private var showsSystemCalendars = false
    /// 주 시작 요일이 바뀌면 격자를 다시 그리도록 읽어 둔다.
    @AppStorage(SettingsKey.weekStart) private var weekStart = 0

    private var mode: CalendarMode {
        CalendarMode(rawValue: modeRaw) ?? .month
    }

    private var month: CalendarMonth {
        CalendarMonth(reference: anchor)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(icon: "calendar", title: title, subtitle: summary) {
                HStack(spacing: 10) {
                    ChipButton(
                        title: "할 일",
                        icon: "checklist",
                        isSelected: showsTasks,
                        help: showsTasks ? "캘린더에서 할 일 숨기기" : "캘린더에 할 일 보이기"
                    ) {
                        withAnimation(DGE.Motion.list) { showsTasks.toggle() }
                    }

                    ModePicker(mode: Binding(
                        get: { mode },
                        set: { newMode in withAnimation(DGE.Motion.list) { modeRaw = newMode.rawValue } }
                    ))

                    DateStepper(
                        onPrevious: { step(-1) },
                        onToday: { withAnimation(DGE.Motion.list) { anchor = Date() } },
                        onNext: { step(1) }
                    )
                }
            }
            .padding(.horizontal, DGE.Spacing.screenHorizontal)
            .padding(.top, DGE.Spacing.screenTop)
            .padding(.bottom, DGE.Spacing.headerBottom)

            board
                .background(DGE.Palette.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DGE.Radius.container, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DGE.Radius.container, style: .continuous)
                        .strokeBorder(DGE.Palette.border, lineWidth: 1)
                )
                .padding(.horizontal, DGE.Spacing.screenHorizontal)
                .padding(.bottom, DGE.Spacing.screenHorizontal - 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id(weekStart)
    }

    @ViewBuilder
    private var board: some View {
        switch mode {
        case .month:
            monthGrid
        case .week, .day:
            TimeGridView(
                days: visibleDays,
                events: events,
                externalEvents: externalEvents,
                tasksByDay: showsTasks ? groupedTasks : [:],
                onSelectEvent: onSelectEvent,
                onSelectTask: onSelectTask,
                onSelectExternal: onSelectExternal,
                onToggleTask: toggle,
                onOpenDay: openDay,
                onCreateEvent: { onSelectEvent(EventStore(context: context).create(at: $0)) },
                onDropOnDay: { drop($0, on: $1) },
                onDropAtTime: { drop($0, at: $1) }
            )
        }
    }

    // MARK: - 월 보기

    private var monthGrid: some View {
        // 칸마다 전체를 훑지 않도록 날짜별로 한 번만 나눠둔다.
        let tasksByDay = showsTasks ? groupedTasks : [:]
        let external = externalEvents

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(month.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(DGE.Typography.calendarWeekday)
                        .foregroundStyle(DGE.Palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 10)
                        .padding(.vertical, 7)
                }
            }
            .background(DGE.Palette.surface)

            ForEach(Array(month.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element) { column, day in
                        DayCell(
                            date: day,
                            isInMonth: month.isInDisplayedMonth(day),
                            showsLeadingLine: column > 0,
                            items: items(on: day, tasks: tasksByDay[Calendar.current.startOfDay(for: day)] ?? [], external: external),
                            onAddEvent: { onSelectEvent(EventStore(context: context).create(on: day)) },
                            onAddTask: { addTask(on: day) },
                            onSelectEvent: onSelectEvent,
                            onSelectTask: onSelectTask,
                            onSelectExternal: onSelectExternal,
                            onToggleTask: toggle,
                            onOpenDay: { openDay(day) },
                            onDrop: { drop($0, on: day) }
                        )
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    /// 일정이 먼저(시간순), macOS 캘린더, 그다음 남은 할 일, 끝낸 할 일은 맨 뒤.
    private func items(on day: Date, tasks dayTasks: [TodoTask], external: [ExternalEvent]) -> [CalendarItem] {
        let dayEvents = events.filter { $0.occurs(on: day) }.map(CalendarItem.event)
        let dayExternal = external.filter { $0.occurs(on: day) }.map(CalendarItem.external)
        let open = dayTasks.filter { !$0.isCompleted }.map(CalendarItem.task)
        let done = dayTasks.filter(\.isCompleted).map(CalendarItem.task)
        return dayEvents + dayExternal + open + done
    }

    // MARK: - 범위

    /// 주 · 일 보기에서 보이는 날들.
    private var visibleDays: [Date] {
        let calendar = Calendar.dge
        switch mode {
        case .day:
            return [calendar.startOfDay(for: anchor)]
        case .week, .month:
            let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? calendar.startOfDay(for: anchor)
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }
    }

    /// 지금 화면에 보이는 기간. macOS 캘린더에서 이 범위만 가져온다.
    private var visibleRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let days = mode == .month ? month.weeks.flatMap { $0 } : visibleDays
        let start = days.first.map { calendar.startOfDay(for: $0) } ?? anchor
        let last = days.last.map { calendar.startOfDay(for: $0) } ?? anchor
        let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return (start, end)
    }

    private var externalEvents: [ExternalEvent] {
        guard showsSystemCalendars else { return [] }
        let system = SystemCalendar.shared
        // 캘린더 앱에서 바뀌면 다시 읽도록 revision을 본다.
        _ = system.revision
        let range = visibleRange
        return system.events(from: range.start, to: range.end)
    }

    private var groupedTasks: [Date: [TodoTask]] {
        let calendar = Calendar.current
        return Dictionary(grouping: tasks.filter { $0.dueDate != nil }) {
            calendar.startOfDay(for: $0.dueDate ?? .distantPast)
        }
    }

    // MARK: - 머리말

    private var title: String {
        switch mode {
        case .month:
            return month.title
        case .week:
            let days = visibleDays
            guard let first = days.first, let last = days.last else { return month.title }
            let format = Date.FormatStyle.dateTime.month(.wide).day()
            return "\(first.formatted(format)) – \(last.formatted(format))"
        case .day:
            return anchor.formatted(.dateTime.month(.wide).day().weekday(.wide))
        }
    }

    /// 보이는 기간에 무엇이 얼마나 있는지.
    private var summary: String {
        let range = visibleRange
        let eventCount = events.filter { event in
            event.startDate < range.end && event.endDate >= range.start
        }.count
        guard showsTasks else { return "일정 \(eventCount)개" }
        let taskCount = tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate >= range.start && dueDate < range.end
        }.count
        return "일정 \(eventCount)개 · 할 일 \(taskCount)개"
    }

    // MARK: - 동작

    private func step(_ value: Int) {
        let component: Calendar.Component = switch mode {
        case .month: .month
        case .week: .weekOfYear
        case .day: .day
        }
        withAnimation(DGE.Motion.list) {
            anchor = Calendar.current.date(byAdding: component, value: value, to: anchor) ?? anchor
        }
    }

    private func openDay(_ day: Date) {
        withAnimation(DGE.Motion.list) {
            anchor = day
            modeRaw = CalendarMode.day.rawValue
        }
    }

    private func addTask(on day: Date) {
        // 숨겨둔 상태에서 만들면 만든 게 안 보이므로 다시 켠다.
        showsTasks = true
        onSelectTask(TaskStore(context: context).createDraft(on: day))
    }

    /// 캘린더에서는 끝낸 할 일도 그 자리에 남는다. 바로 반영한다.
    private func toggle(_ task: TodoTask) {
        withAnimation(DGE.Motion.check) {
            TaskStore(context: context).setCompleted(task, !task.isCompleted)
        }
    }

    /// 다른 날짜 칸(또는 하루 종일 줄)에 놓았을 때. 날짜만 옮긴다.
    private func drop(_ payloads: [String], on day: Date) {
        withAnimation(DGE.Motion.list) {
            for payload in payloads {
                switch CalendarItem.reference(from: payload) {
                case .event(let id):
                    if let event = events.first(where: { $0.id == id }) {
                        EventStore(context: context).move(event, to: day)
                    }
                case .task(let id):
                    if let task = tasks.first(where: { $0.id == id }) {
                        TaskStore(context: context).setDueDate(task, day)
                    }
                case nil:
                    break
                }
            }
        }
    }

    /// 시간 격자에 놓았을 때. 일정은 그 시각으로, 할 일은 그날 그 시각 알림으로.
    private func drop(_ payloads: [String], at time: Date) {
        withAnimation(DGE.Motion.list) {
            for payload in payloads {
                switch CalendarItem.reference(from: payload) {
                case .event(let id):
                    if let event = events.first(where: { $0.id == id }) {
                        EventStore(context: context).move(event, toStart: time)
                    }
                case .task(let id):
                    if let task = tasks.first(where: { $0.id == id }) {
                        let store = TaskStore(context: context)
                        store.setDueDate(task, time)
                        // 날짜를 옮긴 뒤에 시각을 정해야 알림이 놓은 그 시각이 된다.
                        task.remindAt = time
                        store.save()
                        AppServices.shared?.notifications.requestAuthorizationIfNeeded()
                    }
                case nil:
                    break
                }
            }
        }
    }
}

// MARK: - 머리말 도구

/// [일 | 주 | 월] 보기 바꾸기.
private struct ModePicker: View {
    @Binding var mode: CalendarMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CalendarMode.allCases) { item in
                Button {
                    mode = item
                } label: {
                    Text(item.title)
                        .font(.dge(size: 12, weight: mode == item ? .semibold : .regular))
                        .foregroundStyle(mode == item ? DGE.Palette.primaryText : DGE.Palette.secondaryText)
                        .frame(width: 30, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                                .fill(mode == item ? DGE.Palette.selected : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(2)
        .overlay(
            RoundedRectangle(cornerRadius: DGE.Radius.control + 1, style: .continuous)
                .strokeBorder(DGE.Palette.border, lineWidth: 1)
        )
    }
}

/// [‹ 오늘 ›] 한 덩어리로 묶인 이동 버튼.
private struct DateStepper: View {
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            IconButton(icon: "chevron.left", help: "이전", width: 28, height: 26, action: onPrevious)
            divider
            TodayButton(action: onToday)
            divider
            IconButton(icon: "chevron.right", help: "다음", width: 28, height: 26, action: onNext)
        }
        .padding(2)
        .overlay(
            RoundedRectangle(cornerRadius: DGE.Radius.control + 1, style: .continuous)
                .strokeBorder(DGE.Palette.border, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(DGE.Palette.hairline)
            .frame(width: 1, height: 14)
    }
}

private struct TodayButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text("오늘")
                .font(.dge(size: 12, weight: .medium))
                .foregroundStyle(DGE.Palette.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                        .fill(isHovering ? DGE.Palette.selected : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}
