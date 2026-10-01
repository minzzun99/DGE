import SwiftUI
import SwiftData

/// 오른쪽에서 열리는 일정 상세. 창을 새로 띄우지 않는다.
struct EventDetailPanel: View {
    @Bindable var event: CalendarEvent
    let onClose: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @FocusState private var titleFocused: Bool

    private var store: EventStore { EventStore(context: context) }

    private var dateComponents: DatePickerComponents {
        event.isAllDay ? [.date] : [.date, .hourAndMinute]
    }

    var body: some View {
        DetailPanel(kind: "일정", icon: "calendar", onClose: onClose) {
            TextField("제목", text: $event.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(DGE.Typography.panelTitle)
                .lineLimit(1...4)
                .focused($titleFocused)

            VStack(alignment: .leading, spacing: 2) {
                PropertyRow("하루 종일", icon: "sun.horizon") {
                    Toggle("", isOn: allDayBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }

                PropertyRow("시작", icon: "clock") {
                    DatePicker("", selection: $event.startDate, displayedComponents: dateComponents)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .fixedSize()
                }

                PropertyRow("종료", icon: "clock.badge.checkmark") {
                    DatePicker("", selection: $event.endDate, displayedComponents: dateComponents)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .fixedSize()
                }

                PropertyRow("반복", icon: "arrow.clockwise") {
                    Picker("", selection: repeatBinding) {
                        Text("안 함").tag(RepeatRule?.none)
                        Divider()
                        ForEach(RepeatRule.allCases) { rule in
                            Text(rule.title).tag(RepeatRule?.some(rule))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                PropertyRow("알림", icon: "bell") {
                    Picker("", selection: alertBinding) {
                        Text("없음").tag(EventAlert?.none)
                        Divider()
                        ForEach(EventAlert.allCases) { alert in
                            Text(alert.title).tag(EventAlert?.some(alert))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                PropertyRow("위치", icon: "mappin") {
                    TextField("어디에서", text: $event.location)
                        .textFieldStyle(.plain)
                }
            }

            PanelDivider()

            DetailField("설명") {
                TextEditor(text: $event.notes)
                    .font(.dge(size: 12.5))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .dgeFieldBackground(padding: 6)
            }

            PanelDivider()

            DeleteButton(title: "일정 삭제", action: onDelete)
        }
        .onAppear {
            // 방금 만든 빈 일정이면 바로 제목부터 적을 수 있게 한다.
            if event.title.isEmpty { titleFocused = true }
        }
        .onChange(of: event.startDate) { _, _ in
            store.normalize(event)
        }
        .onDisappear {
            store.save()
        }
    }

    private var allDayBinding: Binding<Bool> {
        Binding(
            get: { event.isAllDay },
            set: { store.setAllDay(event, $0) }
        )
    }

    private var repeatBinding: Binding<RepeatRule?> {
        Binding(
            get: { event.repeatRule },
            set: {
                event.repeatRule = $0
                store.save()
            }
        )
    }

    private var alertBinding: Binding<EventAlert?> {
        Binding(
            get: { event.alert },
            set: {
                event.alert = $0
                store.save()
                if $0 != nil { AppServices.shared?.notifications.requestAuthorizationIfNeeded() }
            }
        )
    }
}
