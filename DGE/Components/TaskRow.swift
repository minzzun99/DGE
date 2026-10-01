import SwiftUI

/// 할 일 한 줄.
/// 왼쪽에 체크와 제목, 오른쪽에 메모 · 목록 · 날짜 같은 속성.
/// 마우스를 올리면 속성 자리에 액션 버튼이 대신 뜬다.
struct TaskRow: View {
    let task: TodoTask
    /// 저장된 완료 상태와 별개로, 화면에서 지금 체크되어 보여야 하는지.
    let isChecked: Bool
    var showsDate: Bool = false
    /// 속한 목록의 이름. nil이면 목록 표시를 하지 않는다.
    var listName: String? = nil
    let onToggle: () -> Void
    var onMoveToToday: (() -> Void)? = nil
    var onPostpone: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Checkbox(
                isChecked: isChecked,
                tint: task.isOverdue && !isChecked ? DGE.Palette.overdue : nil,
                action: onToggle
            )

            Text(task.displayTitle)
                .font(DGE.Typography.taskTitle)
                .foregroundStyle(isChecked || task.title.isEmpty ? DGE.Palette.secondaryText : DGE.Palette.primaryText)
                .strikethrough(isChecked, color: DGE.Palette.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            // 두 겹을 겹쳐두고 투명도만 바꾼다. 마우스를 올릴 때 줄 폭이 흔들리지 않게.
            ZStack(alignment: .trailing) {
                properties
                    .opacity(isHovering && hasActions ? 0 : 1)
                actions
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(isHovering)
            }
            // 속성은 줄어들지 않는다. 자리가 모자라면 제목 쪽이 말줄임된다.
            .fixedSize()
        }
        .padding(.vertical, DGE.Spacing.rowVertical)
        .padding(.horizontal, DGE.Spacing.rowHorizontal)
        // 선택 표시는 목록(시스템)이 그린다. 여기서는 hover만.
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.row, style: .continuous)
                .fill(isHovering ? DGE.Palette.hover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }

    // MARK: - 오른쪽

    private var properties: some View {
        HStack(spacing: 8) {
            if task.priority != .none {
                PriorityGlyph(priority: task.priority)
            }

            ForEach(task.tags.prefix(2), id: \.self) { tag in
                TagLabel(tag: tag)
            }
            if task.tags.count > 2 {
                Text("+\(task.tags.count - 2)")
                    .font(DGE.Typography.chip)
                    .foregroundStyle(DGE.Palette.tertiaryText)
            }

            if let progress = task.checklistProgress {
                HStack(spacing: 3) {
                    Image(systemName: "checklist")
                        .font(.dge(size: 10, weight: .medium))
                    Text("\(progress.done)/\(progress.total)")
                        .font(DGE.Typography.meta)
                        .monospacedDigit()
                }
                .foregroundStyle(progress.done == progress.total ? DGE.Palette.accent : DGE.Palette.secondaryText)
                .fixedSize()
                .help("체크리스트 \(progress.done)/\(progress.total)")
            }

            if let rule = task.repeatRule {
                Image(systemName: "arrow.clockwise")
                    .font(.dge(size: 10, weight: .semibold))
                    .foregroundStyle(DGE.Palette.tertiaryText)
                    .help(rule.title)
            }

            if let remindAt = task.remindAt, !task.isCompleted {
                HStack(spacing: 3) {
                    Image(systemName: "bell")
                        .font(.dge(size: 10, weight: .medium))
                    Text(remindAt.dgeTimeText)
                        .font(DGE.Typography.meta)
                        .monospacedDigit()
                }
                .foregroundStyle(remindAt < Date() ? DGE.Palette.overdue : DGE.Palette.secondaryText)
                .fixedSize()
                .help("알림 \(remindAt.dgeShortText) \(remindAt.dgeTimeText)")
            }

            if hasNotes {
                Image(systemName: "text.alignleft")
                    .font(.dge(size: 10.5, weight: .medium))
                    .foregroundStyle(DGE.Palette.tertiaryText)
                    .help("메모 있음")
            }

            if let listName {
                ListTag(name: listName)
            }

            if let dateText {
                Text(dateText)
                    .font(DGE.Typography.meta)
                    .monospacedDigit()
                    .foregroundStyle(task.isOverdue ? DGE.Palette.overdue : DGE.Palette.secondaryText)
                    .fixedSize()
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 2) {
            if canMoveToToday, let onMoveToToday {
                IconButton(icon: "sun.max", help: "오늘로", action: onMoveToToday)
            }
            if canPostpone, let onPostpone {
                IconButton(icon: "arrowshape.turn.up.right", help: "내일로 미루기", action: onPostpone)
            }
            if let onDelete {
                IconButton(icon: "trash", help: "삭제", isDestructive: true, action: onDelete)
            }
        }
    }

    // MARK: - 상태

    private var hasActions: Bool {
        (canMoveToToday && onMoveToToday != nil) || (canPostpone && onPostpone != nil) || onDelete != nil
    }

    private var hasNotes: Bool {
        !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 날짜가 없거나, 지났거나, 앞으로 잡혀 있으면 오늘로 당겨올 수 있다.
    private var canMoveToToday: Bool {
        !task.isCompleted && !task.isScheduledToday
    }

    private var canPostpone: Bool {
        !task.isCompleted && !task.isScheduledTomorrow
    }

    /// 날짜를 보여주기로 한 화면이거나, 기한이 지나서 꼭 알려야 할 때만.
    private var dateText: String? {
        guard showsDate || task.isOverdue else { return nil }
        if task.isCompleted, let completedAt = task.completedAt {
            return completedAt.dgeShortText
        }
        return task.dueDate?.dgeShortText
    }
}
