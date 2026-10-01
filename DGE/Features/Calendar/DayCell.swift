import SwiftUI

/// 캘린더 한 칸. 일정과 할 일을 칩으로 보여주고, 끌어온 칩을 받는다.
struct DayCell: View {
    let date: Date
    let isInMonth: Bool
    /// 맨 왼쪽 칸은 바깥 테두리가 대신하므로 세로선을 그리지 않는다.
    var showsLeadingLine: Bool = true
    let items: [CalendarItem]
    let onAddEvent: () -> Void
    let onAddTask: () -> Void
    let onSelectEvent: (CalendarEvent) -> Void
    let onSelectTask: (TodoTask) -> Void
    let onSelectExternal: (ExternalEvent) -> Void
    let onToggleTask: (TodoTask) -> Void
    /// 날짜 숫자를 누르면 그날 보기로 간다.
    let onOpenDay: () -> Void
    /// 다른 칸에서 끌어온 일정 · 할 일을 이 날짜로 옮긴다.
    let onDrop: ([String]) -> Void

    @State private var isHovering = false
    @State private var isDropTarget = false
    @State private var showsAllItems = false

    private let maxVisibleItems = 3

    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var dayNumber: String { "\(Calendar.current.component(.day, from: date))" }
    private var hiddenCount: Int { max(0, items.count - maxVisibleItems) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            topRow

            ForEach(items.prefix(maxVisibleItems)) { item in
                chip(for: item)
            }

            if hiddenCount > 0 {
                moreButton
            }

            Spacer(minLength: 0)
        }
        .padding(5)
        .frame(maxWidth: .infinity, minHeight: DGE.Size.calendarCellMinHeight, alignment: .topLeading)
        .background(background)
        .overlay(alignment: .top) { line(horizontal: true) }
        .overlay(alignment: .leading) {
            if showsLeadingLine { line(horizontal: false) }
        }
        .overlay {
            if isDropTarget {
                Rectangle()
                    .strokeBorder(DGE.Palette.accent.opacity(0.6), lineWidth: 1.5)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .dropDestination(for: String.self) { payloads, _ in
            onDrop(payloads)
        }
        .onDropSessionUpdated { session in
            switch session.phase {
            case .entering, .active: isDropTarget = true
            default: isDropTarget = false
            }
        }
        .animation(DGE.Motion.hover, value: isHovering)
        .animation(DGE.Motion.hover, value: isDropTarget)
    }

    // MARK: - 머리

    private var topRow: some View {
        HStack(spacing: 4) {
            Button(action: onOpenDay) {
                Text(dayNumber)
                    .font(DGE.Typography.calendarDayNumber)
                    .foregroundStyle(numberColor)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(
                        Circle()
                            .fill(isToday ? DGE.Palette.accent : Color.clear)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.pressable)
            .help("이날 보기")

            Spacer(minLength: 0)

            // 메뉴가 열린 채로 마우스가 나가도 사라지지 않게, 자리는 늘 두고 투명도만 바꾼다.
            Menu {
                Button("일정 추가", systemImage: "calendar", action: onAddEvent)
                Button("할 일 추가", systemImage: "checklist", action: onAddTask)
            } label: {
                Image(systemName: "plus")
                    .font(.dge(size: 11, weight: .medium))
                    .foregroundStyle(DGE.Palette.secondaryText)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                    .fill(DGE.Palette.selected)
            )
            .help("이 날짜에 추가")
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
        }
    }

    private var numberColor: Color {
        if isToday { return .white }
        return isInMonth ? DGE.Palette.primaryText : DGE.Palette.tertiaryText
    }

    // MARK: - 칩

    @ViewBuilder
    private func chip(for item: CalendarItem) -> some View {
        switch item {
        case .event(let event):
            EventChip(event: event, payload: item.id) {
                showsAllItems = false
                onSelectEvent(event)
            }
        case .task(let task):
            TaskChip(
                task: task,
                payload: item.id,
                onToggle: { onToggleTask(task) },
                onSelect: {
                    showsAllItems = false
                    onSelectTask(task)
                }
            )
        case .external(let event):
            ExternalChip(event: event) {
                showsAllItems = false
                onSelectExternal(event)
            }
        }
    }

    /// 칸에 다 못 넣은 것은 눌러서 한꺼번에 본다.
    private var moreButton: some View {
        Button {
            showsAllItems = true
        } label: {
            Text("+\(hiddenCount)개 더")
                .font(DGE.Typography.meta)
                .foregroundStyle(DGE.Palette.secondaryText)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .popover(isPresented: $showsAllItems, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 3) {
                Text(date.dgeHeaderText)
                    .font(DGE.Typography.sectionTitle)
                    .foregroundStyle(DGE.Palette.secondaryText)
                    .padding(.bottom, 5)

                ForEach(items) { item in
                    chip(for: item)
                }
            }
            .padding(12)
            .frame(width: 240, alignment: .leading)
        }
    }

    // MARK: - 바탕

    private var background: Color {
        if isDropTarget { return DGE.Palette.accent.opacity(0.08) }
        if isHovering { return DGE.Palette.hover }
        return isInMonth ? Color.clear : Color.primary.opacity(0.025)
    }

    private func line(horizontal: Bool) -> some View {
        Rectangle()
            .fill(DGE.Palette.gridLine)
            .frame(
                width: horizontal ? nil : 1,
                height: horizontal ? 1 : nil
            )
    }
}

/// 칸 안에 들어가는 일정 한 줄. 왼쪽 파란 막대로 할 일과 구분한다.
struct EventChip: View {
    let event: CalendarEvent
    let payload: String
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(DGE.Palette.accent)
                .frame(width: 2.5)

            Text(event.displayTitle)
                .font(DGE.Typography.chip)
                .foregroundStyle(DGE.Palette.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                .fill(DGE.Palette.accent.opacity(isHovering ? 0.16 : 0.09))
        )
        .contentShape(Rectangle())
        // 버튼 대신 탭 제스처를 쓴다. 버튼은 끌기를 가로챈다.
        .onTapGesture(perform: onSelect)
        .draggable(payload)
        .help("\(event.displayTitle) · \(event.timeRangeText)")
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}

/// 칸 안에 들어가는 할 일 한 줄. 동그라미를 누르면 바로 끝낸다.
struct TaskChip: View {
    let task: TodoTask
    let payload: String
    let onToggle: () -> Void
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            Checkbox(
                isChecked: task.isCompleted,
                size: 11,
                tint: task.isOverdue ? DGE.Palette.overdue : nil,
                action: onToggle
            )

            Text(task.displayTitle)
                .font(DGE.Typography.chip)
                .foregroundStyle(task.isCompleted ? DGE.Palette.secondaryText : DGE.Palette.primaryText)
                .strikethrough(task.isCompleted, color: DGE.Palette.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                .fill(isHovering ? DGE.Palette.selected : DGE.Palette.hover)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .draggable(payload)
        .help(task.displayTitle)
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}

/// macOS 캘린더에서 온 일정. 그 캘린더의 색을 막대로 보여주고, 옮길 수는 없다.
struct ExternalChip: View {
    let event: ExternalEvent
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(event.color)
                .frame(width: 2.5)

            Text(event.title)
                .font(DGE.Typography.chip)
                .foregroundStyle(DGE.Palette.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                .fill(event.color.opacity(isHovering ? 0.2 : 0.11))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .help("\(event.title) · \(event.timeRangeText) · \(event.calendarTitle)")
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}
