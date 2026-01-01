//
//  BoringCalendar.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import SwiftUI

// MARK: - WeekDayPicker
/// Fixed 6-day week view (Mon-Sat) with compact styling
struct WeekDayPicker: View {
    @Binding var selectedDate: Date
    @Environment(\.settings) var settings
    @State private var haptics: Bool = false
    
    /// Get Mon-Sat of the week containing the selected date
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        // Find Monday of this week
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        guard let monday = calendar.date(from: components) else { return [] }
        
        // Generate Mon-Sat (6 days)
        return (0..<6).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
                dayColumn(for: date)
            }
        }
        .sensoryFeedback(.selection, trigger: haptics)
    }
    
    private func dayColumn(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        
        return Button(action: {
            selectedDate = date
            if settings.enableHaptics {
                haptics.toggle()
            }
        }) {
            VStack(spacing: 4) {
                // Day abbreviation (M, T, W, T, F, S)
                Text(dayAbbreviation(for: date))
                    .font(.caption2)
                    .foregroundColor(Color(white: 0.65))
                
                // Date number with circle for today
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.effectiveAccent)
                            .frame(width: 24, height: 24)
                    } else if isSelected {
                        Circle()
                            .fill(Color(white: 0.2))
                            .frame(width: 24, height: 24)
                    }
                    
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isToday || isSelected ? .white : Color(white: 0.65))
                }
                .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter day
        return formatter.string(from: date)
    }
}

struct CalendarView: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Month/Year stacked on left
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.month(.abbreviated)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(selectedDate.formatted(.dateTime.year()))
                        .font(.caption)
                        .fontWeight(.light)
                        .foregroundColor(Color(white: 0.65))
                }
                
                // WeekDayPicker on right (no gradient overlays needed)
                WeekDayPicker(selectedDate: $selectedDate)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)

            let filteredEvents = EventListView.filteredEvents(
                events: calendarManager.events,
                settings: settings
            )
            if filteredEvents.isEmpty {
                EmptyEventsView(selectedDate: selectedDate)
                Spacer(minLength: 0)
            } else {
                EventListView(events: calendarManager.events)
            }
        }
        .listRowBackground(Color.clear)
        .frame(height: 120)
        .onChange(of: selectedDate) {
            Task {
                await calendarManager.updateCurrentDate(selectedDate)
            }
        }
        .onChange(of: vm.notchState) { _, _ in
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
        .onAppear {
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
    }
}

struct EmptyEventsView: View {
    let selectedDate: Date
    
    var body: some View {
        VStack {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title)
                .foregroundColor(Color(white: 0.65))
            Text(Calendar.current.isDateInToday(selectedDate) ? "No events today" : "No events")
                .font(.subheadline)
                .foregroundColor(.white)
            Text("Enjoy your free time!")
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
        }
    }
}

struct EventListView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.settings) var settings
    @ObservedObject private var calendarManager = CalendarManager.shared
    let events: [EventModel]

    static func filteredEvents(events: [EventModel], settings: NotchSettings) -> [EventModel] {
        events.filter { event in
            if event.type.isReminder {
                if case .reminder(let completed) = event.type {
                    return !completed || !settings.hideCompletedReminders
                }
            }
            // Filter out all-day events if setting is enabled
            if event.isAllDay && settings.hideAllDayEvents {
                return false
            }
            return true
        }
    }

    private var filteredEvents: [EventModel] {
        Self.filteredEvents(events: events, settings: settings)
    }

    private func scrollToRelevantEvent(proxy: ScrollViewProxy) {
        let now = Date()
        // Determine a single target using preferred search order:
        // 1) first non-all-day upcoming/in-progress event
        // 2) first all-day event
        // 3) last event (fallback)
        let nonAllDayUpcoming = filteredEvents.first(where: { !$0.isAllDay && $0.end > now })
        let firstAllDay = filteredEvents.first(where: { $0.isAllDay })
        let lastEvent = filteredEvents.last
        guard let target = nonAllDayUpcoming ?? firstAllDay ?? lastEvent else { return }

        Task { @MainActor in
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(target.id, anchor: .top)
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredEvents) { event in
                    Button(action: {
                        if let url = event.calendarAppURL() {
                            openURL(url)
                        }
                    }) {
                        eventRow(event)
                    }
                    .id(event.id)
                    .padding(.leading, -5)
                    .buttonStyle(PlainButtonStyle())
                    .listRowSeparator(.automatic)
                    .listRowSeparatorTint(.gray.opacity(0.2))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onAppear {
                scrollToRelevantEvent(proxy: proxy)
            }
            .onChange(of: filteredEvents) { _, _ in
                scrollToRelevantEvent(proxy: proxy)
            }
        }
        Spacer(minLength: 0)
    }

    private func eventRow(_ event: EventModel) -> some View {
        if event.type.isReminder {
            let isCompleted: Bool
            if case .reminder(let completed) = event.type {
                isCompleted = completed
            } else {
                isCompleted = false
            }
            return AnyView(
                HStack(spacing: 8) {
                    ReminderToggle(
                        isOn: Binding(
                            get: { isCompleted },
                            set: { newValue in
                                Task {
                                    await calendarManager.setReminderCompleted(
                                        reminderID: event.id, completed: newValue
                                    )
                                }
                            }
                        ),
                        color: Color(event.calendar.color)
                    )
                    .opacity(1.0)  // Ensure the toggle is always fully opaque
                    HStack {
                        Text(event.title)
                            .font(.callout)
                            .foregroundColor(.white)
                        Text(event.title)
                            .font(.callout)
                            .foregroundColor(.white)
                            .lineLimit(settings.showFullEventTitles ? nil : 1)
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            if event.isAllDay {
                                Text("All-day")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            } else {
                                Text(event.start, style: .time)
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    }
                    .opacity(
                        isCompleted
                            ? 0.4
                            : event.start < Date.now && Calendar.current.isDateInToday(event.start)
                                ? 0.6 : 1.0
                    )
                }
                .padding(.vertical, 4)
            )
        } else {
            return AnyView(
                HStack(alignment: .top, spacing: 4) {
                    Rectangle()
                        .fill(Color(event.calendar.color))
                        .frame(width: 3)
                        .cornerRadius(1.5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Text(event.title)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(settings.showFullEventTitles ? nil : 2)

                        if let location = event.location, !location.isEmpty {
                            Text(location)
                                .font(.caption)
                                .foregroundColor(Color(white: 0.65))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if event.isAllDay {
                            Text("All-day")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        } else {
                            Text(event.start, style: .time)
                                .foregroundColor(.white)
                            Text(event.end, style: .time)
                                .foregroundColor(Color(white: 0.65))
                        }
                    }
                    .font(.caption)
                    .frame(minWidth: 44, alignment: .trailing)
                }
                .opacity(
                    event.eventStatus == .ended && Calendar.current.isDateInToday(event.start)
                        ? 0.6 : 1.0)
            )
        }
    }
}

struct ReminderToggle: View {
    @Binding var isOn: Bool
    var color: Color

    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 14, height: 14)
                // Inner fill
                if isOn {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Circle()
                    .fill(Color.black.opacity(0.001))
                    .frame(width: 14, height: 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(0)
        .accessibilityLabel(isOn ? "Mark as incomplete" : "Mark as complete")
    }
}

#Preview {
    CalendarView()
        .frame(width: 215, height: 130)
        .background(.black)
        .environment(BoringViewModel())
}
