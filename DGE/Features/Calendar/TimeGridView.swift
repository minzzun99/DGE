import SwiftUI

/// 주 · 일 보기. 위에는 하루 종일 줄(종일 일정 · 시각 없는 할 일), 아래는 시간 격자.
///
/// 빈 칸을 두 번 누르면 그 시각에 일정을 만들고,
/// 일정이나 할 일을 끌어다 놓으면 그 시각으로 옮긴다. (할 일은 그 시각에 알림이 걸린다)
struct TimeGridView: View {
    let days: [Date]
    let events: [CalendarEvent]
    let externalEvents: [ExternalEvent]
    /// 그날 시작 0시를 열쇠로 묶어 둔 할 일.
    let tasksByDay: [Date: [TodoTask]]
    let onSelectEvent: (CalendarEvent) -> Void
    let onSelectTask: (TodoTask) -> Void
    let onSelectExternal: (ExternalEvent) -> Void
    let onToggleTask: (TodoTask) -> Void
    let onOpenDay: (Date) -> Void
    let onCreateEvent: (Date) -> Void
    /// 하루 종일 줄에 놓았을 때. 날짜만 바꾼다.
    let onDropOnDay: ([String], Date) -> Void
    /// 시간 격자에 놓았을 때. 그 시각으로 옮긴다.
    let onDropAtTime: ([String], Date) -> Void

    static let hourHeight: CGFloat = 48
    private let gutter: CGFloat = 58

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
            allDayStrip
            Rectangle().fill(DGE.Palette.border).frame(height: 1)
            timeGrid
        }
    }

    // MARK: - 머리

    private var dayHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutter)
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                Button { onOpenDay(day) } label: {
                    HStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(DGE.Typography.calendarWeekday)
                            .foregroundStyle(DGE.Palette.secondaryText)
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(.dge(size: 15, weight: .semibold).monospacedDigit())
                            .foregroundStyle(isToday ? Color.white : DGE.Palette.primaryText)
                            .frame(minWidth: 26, minHeight: 26)
                            .background(Circle().fill(isToday ? DGE.Palette.accent : Color.clear))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .help("이날 보기")
            }
        }
        .frame(height: 40)
        .background(DGE.Palette.surface)
    }

    // MARK: - 하루 종일

    private var allDayStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("종일")
                .font(.dge(size: 10.5))
                .foregroundStyle(DGE.Palette.tertiaryText)
                .frame(width: gutter - 8, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.top, 6)

            ForEach(days, id: \.self) { day in
                AllDayCell(
                    items: allDayItems(on: day),
                    onSelectEvent: onSelectEvent,
                    onSelectTask: onSelectTask,
                    onSelectExternal: onSelectExternal,
                    onToggleTask: onToggleTask,
                    onDrop: { onDropOnDay($0, day) }
                )
                .overlay(alignment: .leading) {
                    Rectangle().fill(DGE.Palette.gridLine).frame(width: 1)
                }
            }
        }
        .frame(minHeight: 30)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func allDayItems(on day: Date) -> [CalendarItem] {
        let calendar = Calendar.current
        let allDayEvents = events.filter { $0.isAllDay && $0.occurs(on: day) }.map(CalendarItem.event)
        let external = externalEvents.filter { $0.isAllDay && $0.occurs(on: day) }.map(CalendarItem.external)
        let tasks = (tasksByDay[calendar.startOfDay(for: day)] ?? [])
            .filter { !hasTime($0, on: day) }
            .sorted { !$0.isCompleted && $1.isCompleted }
            .map(CalendarItem.task)
        return allDayEvents + external + tasks
    }

    // MARK: - 시간 격자

    private var timeGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    hourLabels
                    ForEach(days, id: \.self) { day in
                        TimeColumn(
                            day: day,
                            blocks: TimeBlock.layout(blocks(on: day)),
                            onSelectEvent: onSelectEvent,
                            onSelectTask: onSelectTask,
                            onSelectExternal: onSelectExternal,
                            onToggleTask: onToggleTask,
                            onCreate: onCreateEvent,
                            onDrop: onDropAtTime
                        )
                        .overlay(alignment: .leading) {
                            Rectangle().fill(DGE.Palette.gridLine).frame(width: 1)
                        }
                    }
                }
                .frame(height: Self.hourHeight * 24)
            }
            // 주 · 날을 넘길 때마다 다시 맞춘다. 격자가 자리를 잡은 다음에 옮겨야 먹힌다.
            .task(id: days.first) {
                try? await Task.sleep(for: .milliseconds(50))
                // 오늘이 보이면 지금 시각 조금 위부터, 아니면 아침 8시부터.
                let showsToday = days.contains { Calendar.current.isDateInToday($0) }
                let hour = showsToday ? max(0, Calendar.current.component(.hour, from: Date()) - 2) : 8
                proxy.scrollTo(hour, anchor: .top)
            }
        }
    }

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(hour == 0 ? "" : hourText(hour))
                    .font(.dge(size: 10.5).monospacedDigit())
                    .foregroundStyle(DGE.Palette.tertiaryText)
                    .frame(width: gutter - 8, height: Self.hourHeight, alignment: .topTrailing)
                    .offset(y: -6)
                    .padding(.trailing, 8)
                    .id(hour)
            }
        }
    }

    private func hourText(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour())
    }

    /// 그날 시간 격자에 놓일 것들. 여러 날에 걸친 일정은 그날 몫만 잘라서.
    private func blocks(on day: Date) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        func clamp(_ start: Date, _ end: Date) -> (Date, Date) {
            let s = max(start, dayStart)
            let e = min(max(end, s.addingTimeInterval(30 * 60)), dayEnd)
            return (s, e)
        }

        var result: [TimeBlock] = []
        for event in events where !event.isAllDay {
            guard let interval = event.occurrence(on: day) else { continue }
            let (s, e) = clamp(interval.start, interval.end)
            result.append(TimeBlock(item: .event(event), start: s, end: e))
        }
        for event in externalEvents where !event.isAllDay && event.occurs(on: day) {
            let (s, e) = clamp(event.start, event.end)
            result.append(TimeBlock(item: .external(event), start: s, end: e))
        }
        for task in tasksByDay[dayStart] ?? [] where hasTime(task, on: day) {
            guard let remindAt = task.remindAt else { continue }
            let (s, e) = clamp(remindAt, remindAt.addingTimeInterval(30 * 60))
            result.append(TimeBlock(item: .task(task), start: s, end: e))
        }
        return result
    }

    /// 알림 시각이 그날 안에 있으면 시간 격자에, 아니면 하루 종일 줄에 둔다.
    private func hasTime(_ task: TodoTask, on day: Date) -> Bool {
        guard let remindAt = task.remindAt else { return false }
        return Calendar.current.isDate(remindAt, inSameDayAs: day)
    }
}

// MARK: - 배치

/// 시간 격자 위의 네모 하나. 겹치면 옆으로 나란히 선다.
struct TimeBlock: Identifiable {
    let item: CalendarItem
    let start: Date
    let end: Date
    var column = 0
    var columns = 1

    var id: String { item.id }

    /// 겹치는 것끼리 묶어 칸을 나눈다. 묶음 안에서 가장 많이 겹친 수만큼 폭을 나눈다.
    static func layout(_ blocks: [TimeBlock]) -> [TimeBlock] {
        let sorted = blocks.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
        var result: [TimeBlock] = []
        var cluster: [TimeBlock] = []
        var columnEnds: [Date] = []
        var clusterEnd = Date.distantPast

        func flush() {
            let count = max(1, columnEnds.count)
            result += cluster.map { block in
                var block = block
                block.columns = count
                return block
            }
            cluster = []
            columnEnds = []
        }

        for var block in sorted {
            if !cluster.isEmpty, block.start >= clusterEnd {
                flush()
            }
            if let free = columnEnds.firstIndex(where: { $0 <= block.start }) {
                block.column = free
                columnEnds[free] = block.end
            } else {
                block.column = columnEnds.count
                columnEnds.append(block.end)
            }
            clusterEnd = cluster.isEmpty ? block.end : max(clusterEnd, block.end)
            cluster.append(block)
        }
        flush()
        return result
    }
}

// MARK: - 하루 종일 칸

private struct AllDayCell: View {
    let items: [CalendarItem]
    let onSelectEvent: (CalendarEvent) -> Void
    let onSelectTask: (TodoTask) -> Void
    let onSelectExternal: (ExternalEvent) -> Void
    let onToggleTask: (TodoTask) -> Void
    let onDrop: ([String]) -> Void

    @State private var isDropTarget = false
    @State private var showsAll = false

    private let maxVisible = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items.prefix(maxVisible)) { chip(for: $0) }
            if items.count > maxVisible {
                Button { showsAll = true } label: {
                    Text("+\(items.count - maxVisible)개 더")
                        .font(DGE.Typography.meta)
                        .foregroundStyle(DGE.Palette.secondaryText)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.pressable)
                .popover(isPresented: $showsAll, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(items) { chip(for: $0) }
                    }
                    .padding(12)
                    .frame(width: 240, alignment: .leading)
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
        .background(isDropTarget ? DGE.Palette.accent.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { payloads, _ in onDrop(payloads) }
        .onDropSessionUpdated { session in
            switch session.phase {
            case .entering, .active: isDropTarget = true
            default: isDropTarget = false
            }
        }
    }

    @ViewBuilder
    private func chip(for item: CalendarItem) -> some View {
        switch item {
        case .event(let event):
            EventChip(event: event, payload: item.id) {
                showsAll = false
                onSelectEvent(event)
            }
        case .task(let task):
            TaskChip(task: task, payload: item.id, onToggle: { onToggleTask(task) }) {
                showsAll = false
                onSelectTask(task)
            }
        case .external(let event):
            ExternalChip(event: event) {
                showsAll = false
                onSelectExternal(event)
            }
        }
    }
}

// MARK: - 시간 칸

private struct TimeColumn: View {
    let day: Date
    let blocks: [TimeBlock]
    let onSelectEvent: (CalendarEvent) -> Void
    let onSelectTask: (TodoTask) -> Void
    let onSelectExternal: (ExternalEvent) -> Void
    let onToggleTask: (TodoTask) -> Void
    let onCreate: (Date) -> Void
    let onDrop: ([String], Date) -> Void

    /// 끌어 놓을 자리를 미리 보여주는 선의 높이.
    @State private var dropY: CGFloat?

    private var hourHeight: CGFloat { TimeGridView.hourHeight }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .topLeading) {
                hourLines

                ForEach(blocks) { block in
                    let frame = frame(for: block, width: width)
                    blockView(block)
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                }

                if isToday {
                    nowLine(width: width)
                }

                if let dropY {
                    Rectangle()
                        .fill(DGE.Palette.accent)
                        .frame(width: width, height: 2)
                        .offset(y: snapped(dropY) - 1)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: hourHeight * 24, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, coordinateSpace: .local) { location in
                onCreate(time(at: location.y))
            }
            .dropDestination(for: String.self) { payloads, session in
                onDrop(payloads, time(at: session.location.y))
                dropY = nil
            }
            .onDropSessionUpdated { session in
                switch session.phase {
                case .entering, .active: dropY = session.location.y
                default: dropY = nil
                }
            }
        }
        .frame(height: hourHeight * 24)
        .help("빈 곳을 두 번 누르면 일정을 만듭니다")
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle().fill(DGE.Palette.gridLine).frame(height: 1)
                    Spacer(minLength: 0)
                    // 30분 선은 더 옅게.
                    Rectangle().fill(DGE.Palette.gridLine.opacity(0.45)).frame(height: 1)
                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight)
            }
        }
        .background(isToday ? DGE.Palette.accent.opacity(0.025) : Color.clear)
    }

    private func nowLine(width: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let y = self.y(for: context.date)
            HStack(spacing: 0) {
                Circle().fill(DGE.Palette.danger).frame(width: 7, height: 7)
                Rectangle().fill(DGE.Palette.danger).frame(height: 1.5)
            }
            .frame(width: width + 3.5)
            .offset(x: -3.5, y: y - 3.5)
            .allowsHitTesting(false)
        }
    }

    // MARK: - 네모

    @ViewBuilder
    private func blockView(_ block: TimeBlock) -> some View {
        let compact = block.end.timeIntervalSince(block.start) < 45 * 60
        switch block.item {
        case .event(let event):
            BlockShell(tint: DGE.Palette.accent, title: event.displayTitle, time: event.timeRangeText, compact: compact)
                .onTapGesture { onSelectEvent(event) }
                .draggable(block.item.id)
                .help("\(event.displayTitle) · \(event.timeRangeText)")
        case .external(let event):
            BlockShell(tint: event.color, title: event.title, time: event.timeRangeText, compact: compact)
                .onTapGesture { onSelectExternal(event) }
                .help("\(event.title) · \(event.calendarTitle)")
        case .task(let task):
            HStack(alignment: .top, spacing: 5) {
                Checkbox(isChecked: task.isCompleted, size: 11, tint: task.isOverdue ? DGE.Palette.overdue : nil) {
                    onToggleTask(task)
                }
                .padding(.top, 1)
                Text(task.displayTitle)
                    .font(.dge(size: 11, weight: .medium))
                    .foregroundStyle(task.isCompleted ? DGE.Palette.secondaryText : DGE.Palette.primaryText)
                    .strikethrough(task.isCompleted, color: DGE.Palette.secondaryText)
                    .lineLimit(compact ? 1 : 2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                    .fill(DGE.Palette.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                    .strokeBorder(DGE.Palette.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { onSelectTask(task) }
            .draggable(block.item.id)
            .help(task.displayTitle)
        }
    }

    // MARK: - 좌표

    private func frame(for block: TimeBlock, width: CGFloat) -> CGRect {
        let top = y(for: block.start)
        let bottom = y(for: block.end)
        let columnWidth = (width - 4) / CGFloat(block.columns)
        return CGRect(
            x: 2 + columnWidth * CGFloat(block.column),
            y: top + 1,
            width: max(10, columnWidth - 2),
            height: max(18, bottom - top - 2)
        )
    }

    private func y(for date: Date) -> CGFloat {
        let start = Calendar.current.startOfDay(for: day)
        let minutes = date.timeIntervalSince(start) / 60
        return CGFloat(minutes / 60) * hourHeight
    }

    /// 15분 단위로 맞춘다.
    private func snapped(_ y: CGFloat) -> CGFloat {
        let quarter = hourHeight / 4
        return (y / quarter).rounded(.down) * quarter
    }

    private func time(at y: CGFloat) -> Date {
        let minutes = Int((snapped(max(0, y)) / hourHeight) * 60)
        let clamped = min(minutes, 24 * 60 - 15)
        let start = Calendar.current.startOfDay(for: day)
        return Calendar.current.date(byAdding: .minute, value: clamped, to: start) ?? start
    }
}

/// 시간 격자 위 일정 네모의 모양. 왼쪽 막대 색으로 어느 캘린더인지 구분한다.
private struct BlockShell: View {
    let tint: Color
    let title: String
    let time: String
    let compact: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(tint)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.dge(size: 11, weight: .semibold))
                    .foregroundStyle(DGE.Palette.primaryText)
                    .lineLimit(compact ? 1 : 2)
                if !compact {
                    Text(time)
                        .font(.dge(size: 10).monospacedDigit())
                        .foregroundStyle(DGE.Palette.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                .fill(tint.opacity(isHovering ? 0.22 : 0.14))
        )
        .clipShape(RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}
