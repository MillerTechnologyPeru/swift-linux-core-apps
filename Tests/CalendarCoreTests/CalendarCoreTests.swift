//
//  CalendarCoreTests.swift
//  CoreApps
//

import Testing
@testable import CalendarCore

func day(_ year: Int, _ month: Int, _ day: Int) -> CivilDate {
    CivilDate(year: year, month: month, day: day)
}

func at(_ date: CivilDate, _ hour: Int, _ minute: Int = 0) -> DateTime {
    DateTime(date: date, hour: hour, minute: minute)
}

@Suite struct CivilDateTests {

    @Test func countsDaysBothWays() {
        let date = day(2026, 11, 22)
        #expect(CivilDate(daysSince1970: date.daysSince1970) == date)
        #expect(day(1970, 1, 1).daysSince1970 == 0)
        #expect(CivilDate(daysSince1970: -1) == day(1969, 12, 31))
    }

    @Test func knowsTheDayOfTheWeek() {
        #expect(day(2026, 11, 22).weekday == 0)
        #expect(day(2026, 11, 27).weekday == 5)
        #expect(day(2000, 2, 29).weekday == 2)
    }

    @Test func addsMonthsKeepingToTheMonthsLength() {
        #expect(day(2026, 1, 31).adding(months: 1) == day(2026, 2, 28))
        #expect(day(2024, 1, 31).adding(months: 1) == day(2024, 2, 29))
        #expect(day(2026, 1, 15).adding(months: -1) == day(2025, 12, 15))
        #expect(day(2026, 11, 22).adding(months: 14) == day(2028, 1, 22))
    }

    @Test func readsDates() {
        #expect(CivilDate("2026-11-22") == day(2026, 11, 22))
        #expect(CivilDate("20261122") == day(2026, 11, 22))
        #expect(CivilDate("20260230") == nil)
        #expect(CivilDate("2026112") == nil)
        #expect(day(2026, 1, 5).compact == "20260105")
    }

    @Test func findsTheStartOfTheWeek() {
        #expect(day(2026, 11, 25).startOfWeek(firstWeekday: 0) == day(2026, 11, 22))
        #expect(day(2026, 11, 25).startOfWeek(firstWeekday: 1) == day(2026, 11, 23))
        #expect(day(2026, 11, 22).startOfWeek(firstWeekday: 1) == day(2026, 11, 16))
    }

    @Test func readsAndMovesTimes() {
        let time = DateTime("20261122T093000Z")
        #expect(time == at(day(2026, 11, 22), 9, 30))
        #expect(DateTime("20261122") == nil)
        #expect(at(day(2026, 11, 22), 23, 30).adding(minutes: 45) == at(day(2026, 11, 23), 0, 15))
        #expect(DateTime(minutesSince1970: at(day(1969, 12, 31), 23, 59).minutesSince1970) == at(day(1969, 12, 31), 23, 59))
        #expect(at(day(2026, 11, 22), 9, 5).compact == "20261122T090500")
    }
}

@Suite struct RecurrenceTests {

    @Test func readsAndWritesRules() {
        let rule = Recurrence(rule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=10")
        #expect(rule?.frequency == .weekly)
        #expect(rule?.interval == 2)
        #expect(rule?.weekdays.map(\.weekday) == [1, 3])
        #expect(rule?.count == 10)
        #expect(rule?.rule() == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=10")
        #expect(Recurrence(rule: "FREQ=MONTHLY;BYDAY=-1FR")?.weekdays == [.init(weekday: 5, ordinal: -1)])
        #expect(Recurrence(rule: "FREQ=DAILY;UNTIL=20261231T235959Z")?.until == day(2026, 12, 31))
        #expect(Recurrence(rule: "INTERVAL=2") == nil)
    }

    @Test func repeatsDaily() {
        let rule = Recurrence(frequency: .daily, count: 3)
        #expect(rule.dates(from: day(2026, 11, 22), through: day(2026, 12, 31)) == [day(2026, 11, 22), day(2026, 11, 23), day(2026, 11, 24)])
        let until = Recurrence(frequency: .daily, interval: 2, until: day(2026, 11, 26))
        #expect(until.dates(from: day(2026, 11, 22), through: day(2026, 12, 31)) == [day(2026, 11, 22), day(2026, 11, 24), day(2026, 11, 26)])
    }

    @Test func repeatsOnWeekdays() {
        let rule = Recurrence(frequency: .weekly, weekdays: [.init(weekday: 1), .init(weekday: 3)])
        #expect(rule.dates(from: day(2026, 11, 23), through: day(2026, 12, 6))
            == [day(2026, 11, 23), day(2026, 11, 25), day(2026, 11, 30), day(2026, 12, 2)])
        // From a Wednesday, the Monday before isn't one.
        #expect(rule.dates(from: day(2026, 11, 25), through: day(2026, 12, 2)) == [day(2026, 11, 25), day(2026, 11, 30), day(2026, 12, 2)])
        var fortnightly = rule
        fortnightly.interval = 2
        #expect(fortnightly.dates(from: day(2026, 11, 23), through: day(2026, 12, 9))
            == [day(2026, 11, 23), day(2026, 11, 25), day(2026, 12, 7), day(2026, 12, 9)])
    }

    @Test func repeatsMonthlySkippingShortMonths() {
        let rule = Recurrence(frequency: .monthly)
        #expect(rule.dates(from: day(2026, 1, 31), through: day(2026, 6, 30)) == [day(2026, 1, 31), day(2026, 3, 31), day(2026, 5, 31)])
    }

    @Test func repeatsOnTheNthWeekdayOfTheMonth() {
        let second = Recurrence(frequency: .monthly, weekdays: [.init(weekday: 1, ordinal: 2)])
        #expect(second.dates(from: day(2026, 11, 9), through: day(2027, 1, 31)) == [day(2026, 11, 9), day(2026, 12, 14), day(2027, 1, 11)])
        let last = Recurrence(frequency: .monthly, weekdays: [.init(weekday: 5, ordinal: -1)])
        #expect(last.dates(from: day(2026, 11, 1), through: day(2026, 12, 31)) == [day(2026, 11, 27), day(2026, 12, 25)])
        let lastDay = Recurrence(frequency: .monthly, monthDays: [-1])
        #expect(lastDay.dates(from: day(2026, 1, 31), through: day(2026, 3, 31)) == [day(2026, 1, 31), day(2026, 2, 28), day(2026, 3, 31)])
    }

    @Test func repeatsYearlyOnLeapDaysOnlyInLeapYears() {
        let rule = Recurrence(frequency: .yearly)
        #expect(rule.dates(from: day(2024, 2, 29), through: day(2033, 1, 1)) == [day(2024, 2, 29), day(2028, 2, 29), day(2032, 2, 29)])
    }

    @Test func saysItselfInWords() {
        #expect(Recurrence(frequency: .weekly, interval: 2, weekdays: [.init(weekday: 1), .init(weekday: 3)]).summary
            == "Every 2 weeks on Monday and Wednesday")
        #expect(Recurrence.Preset.weekdays.recurrence(startingOn: day(2026, 11, 23))?.summary == "Every weekday")
        #expect(Recurrence(frequency: .monthly, weekdays: [.init(weekday: 1, ordinal: 2)]).summary == "Every month on the second Monday")
        #expect(Recurrence(frequency: .daily, count: 3).summary == "Every day, 3 times")
        #expect(Recurrence(frequency: .yearly, until: day(2030, 1, 1)).summary == "Every year, until Jan 1, 2030")
        #expect(Recurrence(frequency: .monthly, monthDays: [1, 15]).summary == "Every month on the 1st and 15th")
    }

    @Test func knowsItsPreset() {
        let monday = day(2026, 11, 23)
        for preset in Recurrence.Preset.allCases where preset != .never {
            #expect(preset.recurrence(startingOn: monday)?.preset(startingOn: monday) == preset)
        }
        var ending = Recurrence.Preset.weekly.recurrence(startingOn: monday)
        ending?.count = 4
        #expect(ending?.preset(startingOn: monday) == .weekly)
        #expect(Recurrence(frequency: .daily, interval: 3).preset(startingOn: monday) == nil)
    }
}

@Suite struct EventTests {

    func standUp() -> Event {
        var event = Event(title: "Stand-up", calendarID: "work", start: at(day(2026, 11, 23), 9), end: at(day(2026, 11, 23), 9, 15))
        event.recurrence = Recurrence(frequency: .weekly, weekdays: [.init(weekday: 1)])
        event.exceptions = [day(2026, 11, 30)]
        return event
    }

    @Test func repeatsLessItsExceptions() {
        let occurrences = standUp().occurrences(from: DateTime(date: day(2026, 11, 22)), to: DateTime(date: day(2026, 12, 8)))
        #expect(occurrences.map(\.start) == [at(day(2026, 11, 23), 9), at(day(2026, 12, 7), 9)])
        #expect(occurrences.allSatisfy { $0.start.minutes(to: $0.end) == 15 })
    }

    @Test func findsAnOccurrenceThatStartedEarlier() {
        let night = Event(title: "Night shift", calendarID: "work", start: at(day(2026, 11, 22), 23), end: at(day(2026, 11, 23), 1))
        let occurrences = night.occurrences(from: DateTime(date: day(2026, 11, 23)), to: DateTime(date: day(2026, 11, 24)))
        #expect(occurrences.count == 1)
        #expect(occurrences[0].days == [day(2026, 11, 22), day(2026, 11, 23)])
    }

    @Test func coversTheDaysOfAnAllDayEvent() {
        let trip = Event(title: "Trip", calendarID: "home", start: DateTime(date: day(2026, 11, 22)), end: DateTime(date: day(2026, 11, 24)), isAllDay: true)
        let occurrence = trip.occurrences(from: DateTime(date: day(2026, 11, 1)), to: DateTime(date: day(2026, 12, 1)))[0]
        #expect(occurrence.days == [day(2026, 11, 22), day(2026, 11, 23)])
        let reminder = Event(title: "Call", calendarID: "home", start: at(day(2026, 11, 22), 10), end: at(day(2026, 11, 22), 10))
        #expect(reminder.occurrences(from: at(day(2026, 11, 22), 10), to: at(day(2026, 11, 22), 11)).count == 1)
    }

    @Test func laysOutDaysWithAllDayEventsFirst() {
        let trip = Event(title: "Trip", calendarID: "home", start: DateTime(date: day(2026, 11, 23)), end: DateTime(date: day(2026, 11, 24)), isAllDay: true)
        let days = Agenda.days([standUp(), trip], from: day(2026, 11, 22), through: day(2026, 11, 28))
        #expect(days[day(2026, 11, 23)]?.map(\.event.title) == ["Trip", "Stand-up"])
        #expect(days[day(2026, 11, 22)] == nil)
        #expect(days.count == 1)
    }

    @Test func gridsTheMonth() {
        let sundays = Agenda.weeks(of: day(2026, 11, 15), firstWeekday: 0)
        #expect(sundays.count == 5)
        #expect(sundays[0][0] == day(2026, 11, 1))
        #expect(sundays[4][6] == day(2026, 12, 5))
        let mondays = Agenda.weeks(of: day(2026, 11, 15), firstWeekday: 1)
        #expect(mondays.count == 6)
        #expect(mondays[0][0] == day(2026, 10, 26))
    }

    @Test func comesDueForAnAlert() {
        var lunch = Event(title: "Lunch", calendarID: "home", start: at(day(2026, 11, 22), 12), end: at(day(2026, 11, 22), 13))
        lunch.alert = 15
        #expect(Agenda.alerts([lunch], after: at(day(2026, 11, 22), 11, 40), upTo: at(day(2026, 11, 22), 11, 46)).count == 1)
        #expect(Agenda.alerts([lunch], after: at(day(2026, 11, 22), 11, 46), upTo: at(day(2026, 11, 22), 11, 50)).isEmpty)
        var weekly = standUp()
        weekly.alert = 0
        let due = Agenda.alerts([weekly], after: at(day(2026, 12, 7), 8, 59), upTo: at(day(2026, 12, 7), 9))
        #expect(due.map(\.start) == [at(day(2026, 12, 7), 9)])
    }
}

@Suite struct ICalendarTests {

    /// The local clock is five hours behind UTC, and London's is UTC.
    static func toLocal(_ time: ICalendarTime) -> DateTime {
        switch time {
        case let .date(day): DateTime(date: day)
        case let .floating(time): time
        case let .utc(time), let .zoned(time, _): time.adding(minutes: -300)
        }
    }

    static let sample = """
    BEGIN:VCALENDAR\r
    VERSION:2.0\r
    PRODID:-//Example//EN\r
    BEGIN:VTIMEZONE\r
    TZID:Europe/London\r
    BEGIN:STANDARD\r
    DTSTART:19701025T020000\r
    TZOFFSETFROM:+0100\r
    TZOFFSETTO:+0000\r
    END:STANDARD\r
    END:VTIMEZONE\r
    BEGIN:VEVENT\r
    UID:standup@example.com\r
    DTSTART;TZID=Europe/London:20261123T140000\r
    DURATION:PT15M\r
    RRULE:FREQ=WEEKLY;BYDAY=MO\r
    EXDATE;TZID=Europe/London:20261130T140000\r
    SUMMARY:Stand-up\r
    LOCATION:Room 4\\, second floor\r
    DESCRIPTION:Bring notes.\\nKeep it short.\r
    BEGIN:VALARM\r
    ACTION:DISPLAY\r
    TRIGGER:-PT10M\r
    END:VALARM\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:standup@example.com\r
    RECURRENCE-ID;TZID=Europe/London:20261207T140000\r
    DTSTART;TZID=Europe/London:20261207T150000\r
    DTEND;TZID=Europe/London:20261207T151500\r
    SUMMARY:Stand-up (moved)\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:holiday@example.com\r
    DTSTART;VALUE=DATE:20261224\r
    DTEND;VALUE=DATE:20261227\r
    SUMMARY:Holiday\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    UID:call@example.com\r
    DTSTART:20261122T180000Z\r
    DTEND:20261122T183000Z\r
    SUMMARY:Call\r
    END:VEVENT\r
    END:VCALENDAR\r

    """

    @Test func readsEvents() {
        let events = ICalendar.parse(Self.sample, calendarID: "work", toLocal: Self.toLocal)
        #expect(events.map(\.title) == ["Stand-up", "Holiday", "Call", "Stand-up (moved)"])
        let standUp = events[0]
        #expect(standUp.start == at(day(2026, 11, 23), 9))
        #expect(standUp.duration == 15)
        #expect(standUp.location == "Room 4, second floor")
        #expect(standUp.notes == "Bring notes.\nKeep it short.")
        #expect(standUp.alert == 10)
        #expect(standUp.recurrence?.frequency == .weekly)
        #expect(standUp.exceptions == [day(2026, 11, 30), day(2026, 12, 7)])
        #expect(standUp.calendarID == "work")
        let holiday = events[1]
        #expect(holiday.isAllDay)
        #expect(holiday.end == DateTime(date: day(2026, 12, 27)))
        #expect(events[2].start == at(day(2026, 11, 22), 13))
        let moved = events[3]
        #expect(moved.id == "standup@example.com-20261207")
        #expect(moved.start == at(day(2026, 12, 7), 10))
    }

    @Test func readsDurations() {
        #expect(ICalendar.parseDuration("-PT15M") == -15)
        #expect(ICalendar.parseDuration("P1D") == 1440)
        #expect(ICalendar.parseDuration("PT1H30M") == 90)
        #expect(ICalendar.parseDuration("P1W") == 10_080)
        #expect(ICalendar.parseDuration("PT0S") == 0)
        #expect(ICalendar.parseDuration("15M") == nil)
    }

    @Test func writesAndReadsBack() {
        let events = ICalendar.parse(Self.sample, calendarID: "work", toLocal: Self.toLocal)
        let text = ICalendar.write(events, stamp: at(day(2026, 11, 22), 12)) { $0.adding(minutes: 300) }
        #expect(text.hasPrefix("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"))
        #expect(text.contains("\r\nDTSTART:20261123T140000Z\r\n"))
        #expect(text.contains("\r\nDTSTART;VALUE=DATE:20261224\r\n"))
        #expect(text.contains("\r\nLOCATION:Room 4\\, second floor\r\n"))
        #expect(text.contains("\r\nTRIGGER:-PT10M\r\n"))
        let read = ICalendar.parse(text, calendarID: "work", toLocal: Self.toLocal)
        #expect(read.count == events.count)
        for (copy, original) in zip(read, events) {
            #expect(copy.id == original.id)
            #expect(copy.title == original.title)
            #expect(copy.start == original.start)
            #expect(copy.end == original.end)
            #expect(copy.isAllDay == original.isAllDay)
            #expect(copy.recurrence == original.recurrence)
            #expect(copy.exceptions == original.exceptions)
            #expect(copy.alert == original.alert)
            #expect(copy.notes == original.notes)
        }
    }

    @Test func writesUntilAsTheDaysEnd() {
        var event = Event(title: "Class", calendarID: "home", start: at(day(2026, 11, 23), 18), end: at(day(2026, 11, 23), 19))
        event.recurrence = Recurrence(frequency: .weekly, weekdays: [.init(weekday: 1)], until: day(2026, 12, 21))
        let text = ICalendar.write([event], stamp: at(day(2026, 11, 22), 12)) { $0 }
        #expect(text.contains("RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20261221T235900Z"))
    }
}

@Suite struct CalendarTextTests {

    let today = day(2026, 11, 22)

    @Test func writesDates() {
        #expect(CalendarText.month(today) == "November 2026")
        #expect(CalendarText.longDate(day(2026, 11, 23), today: today) == "Monday, November 23")
        #expect(CalendarText.longDate(day(2027, 1, 1), today: today) == "Friday, January 1, 2027")
        #expect(CalendarText.relativeDate(day(2026, 11, 23), today: today) == "Tomorrow")
        #expect(CalendarText.relativeDate(day(2026, 11, 21), today: today) == "Yesterday")
        #expect(CalendarText.weekdayInitials(firstWeekday: 1) == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test func writesTimes() {
        #expect(CalendarText.time(at(today, 9, 30), uses24Hour: false) == "9:30 AM")
        #expect(CalendarText.time(at(today, 0, 5), uses24Hour: false) == "12:05 AM")
        #expect(CalendarText.time(at(today, 12), uses24Hour: false) == "12:00 PM")
        #expect(CalendarText.time(at(today, 21, 5), uses24Hour: true) == "21:05")
    }

    @Test func writesSpans() {
        let event = Event(title: "Night shift", calendarID: "work", start: at(today, 22), end: at(today.adding(days: 1), 6))
        let occurrence = Occurrence(event: event, start: event.start, end: event.end)
        #expect(CalendarText.span(occurrence, on: today, uses24Hour: false) == "from 10:00 PM")
        #expect(CalendarText.span(occurrence, on: today.adding(days: 1), uses24Hour: false) == "until 6:00 AM")
        let lunch = Event(title: "Lunch", calendarID: "home", start: at(today, 12), end: at(today, 13))
        #expect(CalendarText.span(Occurrence(event: lunch, start: lunch.start, end: lunch.end), on: today, uses24Hour: true) == "12:00 – 13:00")
        #expect(CalendarText.fullSpan(Occurrence(event: lunch, start: lunch.start, end: lunch.end), today: today, uses24Hour: false)
            == ["Sunday, November 22", "12:00 PM – 1:00 PM"])
    }

    @Test func writesDurationsAndAlerts() {
        #expect(CalendarText.duration(90) == "1 hr 30 min")
        #expect(CalendarText.duration(45) == "45 min")
        #expect(CalendarText.duration(2880) == "2 days")
        #expect(CalendarText.alert(nil) == "None")
        #expect(CalendarText.alert(0) == "At time of event")
        #expect(CalendarText.alert(15) == "15 minutes before")
        #expect(CalendarText.alert(120) == "2 hours before")
        #expect(CalendarText.alert(1440) == "1 day before")
        #expect(CalendarText.alert(10_080) == "1 week before")
    }

    @Test func remindsInWords() {
        let lunch = Event(title: "Lunch", calendarID: "home", start: at(today, 12), end: at(today, 13))
        let occurrence = Occurrence(event: lunch, start: lunch.start, end: lunch.end)
        #expect(CalendarText.reminder(occurrence, now: at(today, 11, 45), uses24Hour: false) == "Lunch in 15 minutes")
        #expect(CalendarText.reminder(occurrence, now: at(today, 12), uses24Hour: false) == "Lunch is now")
        #expect(CalendarText.reminder(occurrence, now: at(today, 10), uses24Hour: false) == "Lunch today at 12:00 PM")
        #expect(CalendarText.reminder(occurrence, now: at(today.adding(days: -1), 12), uses24Hour: false) == "Lunch tomorrow at 12:00 PM")
    }
}
