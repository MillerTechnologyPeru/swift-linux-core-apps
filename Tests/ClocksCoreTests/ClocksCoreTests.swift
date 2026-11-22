import Testing
@testable import ClocksCore

@Suite struct WeekdaysTests {

    @Test func summaries() {
        #expect(Weekdays().summary == "Never")
        #expect(Weekdays.everyDay.summary == "Every day")
        #expect(Weekdays.weekdays.summary == "Weekdays")
        #expect(Weekdays.weekend.summary == "Weekends")
        #expect(Weekdays([.monday, .wednesday, .friday]).summary == "Mon Wed Fri")
        #expect(Weekdays([.sunday, .saturday, .tuesday]).summary == "Sun Tue Sat")
    }

    @Test func daysFromTheirNumbers() {
        #expect(Weekdays(day: 0) == .sunday)
        #expect(Weekdays(day: 6) == .saturday)
        #expect(Weekdays(day: 7) == .sunday)
        #expect(Weekdays(day: -1) == .saturday)
    }
}

@Suite struct AlarmTests {

    /// Wednesday, 08:00.
    private let wednesdayMorning = LocalTime(weekday: 3, hour: 8, minute: 0)

    @Test func aOnceAlarmLaterTodayGoesOffToday() {
        let alarm = Alarm(id: "a", hour: 9, minute: 30)
        #expect(alarm.secondsUntilNext(from: wednesdayMorning) == 5400)
    }

    @Test func aOnceAlarmEarlierTodayGoesOffTomorrow() {
        let alarm = Alarm(id: "a", hour: 7, minute: 0)
        #expect(alarm.secondsUntilNext(from: wednesdayMorning) == 82_800)
    }

    @Test func anAlarmAtThisVeryMomentIsTomorrows() {
        let alarm = Alarm(id: "a", hour: 8, minute: 0)
        #expect(alarm.secondsUntilNext(from: wednesdayMorning) == 86_400)
    }

    @Test func anAlarmOffNeverGoesOff() {
        let alarm = Alarm(id: "a", hour: 9, minute: 0, isEnabled: false)
        #expect(alarm.secondsUntilNext(from: wednesdayMorning) == nil)
    }

    @Test func aRepeatingAlarmWaitsForItsDay() {
        // Fridays at 07:00, from Wednesday at 08:00: two days less an hour.
        let alarm = Alarm(id: "a", hour: 7, minute: 0, days: .friday)
        #expect(alarm.secondsUntilNext(from: wednesdayMorning) == 169_200)
        // Weekdays at 09:00 goes off today.
        let weekdays = Alarm(id: "b", hour: 9, minute: 0, days: .weekdays)
        #expect(weekdays.secondsUntilNext(from: wednesdayMorning) == 3600)
    }

    @Test func aWeeklyAlarmPastForTodayWaitsAWeek() {
        let alarm = Alarm(id: "a", hour: 7, minute: 0, days: .wednesday)
        #expect(alarm.secondsUntilNext(from: wednesdayMorning) == 601_200)
    }

    @Test func weekendAlarmsSkipTheWeek() {
        // Friday 23:00 to Saturday 06:30.
        let friday = LocalTime(weekday: 5, hour: 23, minute: 0)
        let alarm = Alarm(id: "a", hour: 6, minute: 30, days: .weekend)
        #expect(alarm.secondsUntilNext(from: friday) == 7.5 * 3600)
    }

    @Test func goingOffBetweenTwoMoments() {
        let alarm = Alarm(id: "a", hour: 8, minute: 0)
        let before = LocalTime(weekday: 3, hour: 7, minute: 59, second: 59)
        let at = LocalTime(weekday: 3, hour: 8, minute: 0)
        let after = LocalTime(weekday: 3, hour: 8, minute: 0, second: 1)
        #expect(alarm.goesOff(after: before, until: at))
        #expect(alarm.goesOff(after: before, until: after))
        #expect(!alarm.goesOff(after: at, until: after))
        #expect(!alarm.goesOff(after: LocalTime(weekday: 3, hour: 6, minute: 0), until: before))
    }

    @Test func goingOffAcrossMidnight() {
        let alarm = Alarm(id: "a", hour: 0, minute: 0)
        let late = LocalTime(weekday: 6, hour: 23, minute: 59, second: 50)
        let early = LocalTime(weekday: 0, hour: 0, minute: 0, second: 5)
        #expect(alarm.goesOff(after: late, until: early))
    }

    @Test func titles() {
        #expect(Alarm(id: "a", hour: 0, minute: 0).title == "Alarm")
        #expect(Alarm(id: "a", hour: 0, minute: 0, label: "Gym").title == "Gym")
    }
}

@Suite struct StopwatchTests {

    @Test func itRunsStopsAndRunsOn() {
        var stopwatch = Stopwatch()
        #expect(stopwatch.isReset)
        stopwatch.start(at: 10)
        #expect(stopwatch.elapsed(at: 13) == 3)
        stopwatch.stop(at: 15)
        #expect(stopwatch.elapsed(at: 100) == 5)
        stopwatch.start(at: 200)
        #expect(stopwatch.elapsed(at: 202) == 7)
        #expect(!stopwatch.isReset)
    }

    @Test func startingTwiceAndStoppingTwiceChangeNothing() {
        var stopwatch = Stopwatch()
        stopwatch.start(at: 0)
        stopwatch.start(at: 5)
        #expect(stopwatch.elapsed(at: 10) == 10)
        stopwatch.stop(at: 10)
        stopwatch.stop(at: 20)
        #expect(stopwatch.elapsed(at: 30) == 10)
    }

    @Test func lapsAreTheTimesBetweenTaps() {
        var stopwatch = Stopwatch()
        stopwatch.start(at: 0)
        stopwatch.lap(at: 4)
        stopwatch.lap(at: 6)
        stopwatch.lap(at: 13)
        #expect(stopwatch.laps == [4, 2, 7])
        #expect(stopwatch.currentLap(at: 14) == 1)
        #expect(stopwatch.fastestLap == 1)
        #expect(stopwatch.slowestLap == 2)
        // A stopped stopwatch takes no laps.
        stopwatch.stop(at: 15)
        stopwatch.lap(at: 16)
        #expect(stopwatch.laps.count == 3)
    }

    @Test func oneLapIsNeitherFastestNorSlowest() {
        var stopwatch = Stopwatch()
        stopwatch.start(at: 0)
        stopwatch.lap(at: 1)
        #expect(stopwatch.fastestLap == nil)
        #expect(stopwatch.slowestLap == nil)
    }

    @Test func resetGoesBackToZero() {
        var stopwatch = Stopwatch()
        stopwatch.start(at: 0)
        stopwatch.lap(at: 1)
        stopwatch.reset()
        #expect(stopwatch.isReset)
        #expect(stopwatch.elapsed(at: 50) == 0)
    }
}

@Suite struct CountdownTimerTests {

    @Test func itCountsDownToNothing() {
        var timer = CountdownTimer(duration: 60)
        #expect(!timer.isStarted)
        #expect(timer.remaining(at: 0) == 60)
        timer.start(at: 100)
        #expect(timer.remaining(at: 130) == 30)
        #expect(timer.progress(at: 130) == 0.5)
        #expect(!timer.isFinished(at: 159))
        #expect(timer.isFinished(at: 160))
        #expect(timer.remaining(at: 500) == 0)
    }

    @Test func pausingHoldsTheTimeLeft() {
        var timer = CountdownTimer(duration: 60)
        timer.start(at: 0)
        timer.pause(at: 20)
        #expect(timer.isPaused)
        #expect(timer.remaining(at: 1000) == 40)
        timer.start(at: 1000)
        #expect(timer.remaining(at: 1010) == 30)
    }

    @Test func cancellingGoesBackToTheLengthSet() {
        var timer = CountdownTimer(duration: 60)
        timer.start(at: 0)
        timer.cancel()
        #expect(!timer.isStarted && !timer.isRunning)
        #expect(timer.remaining(at: 99) == 60)
    }

    @Test func addingTimeWhileRunning() {
        var timer = CountdownTimer(duration: 60)
        timer.start(at: 0)
        timer.add(60, at: 50)
        #expect(timer.remaining(at: 50) == 70)
        #expect(timer.remaining(at: 60) == 60)
        #expect(timer.duration == 120)
    }

    @Test func aTimerOfNothingDoesNotStart() {
        var timer = CountdownTimer(duration: 0)
        timer.start(at: 0)
        #expect(!timer.isStarted)
        #expect(CountdownTimer(duration: -5).duration == 0)
    }
}

@Suite struct TimeTextTests {

    @Test func stopwatchTimes() {
        #expect(TimeText.stopwatch(0) == "00:00.00")
        #expect(TimeText.stopwatch(7.439) == "00:07.43")
        #expect(TimeText.stopwatch(127.5) == "02:07.50")
        #expect(TimeText.stopwatch(3727.25) == "1:02:07.25")
        #expect(TimeText.stopwatch(-1) == "00:00.00")
    }

    @Test func countdownTimesRoundUp() {
        #expect(TimeText.countdown(0) == "0:00")
        #expect(TimeText.countdown(0.2) == "0:01")
        #expect(TimeText.countdown(245) == "4:05")
        #expect(TimeText.countdown(3600) == "1:00:00")
    }

    @Test func timesOfDay() {
        #expect(TimeText.timeOfDay(hour: 7, minute: 5, uses24Hour: true) == "07:05")
        #expect(TimeText.timeOfDay(hour: 0, minute: 0, uses24Hour: false) == "12:00 AM")
        #expect(TimeText.timeOfDay(hour: 12, minute: 30, uses24Hour: false) == "12:30 PM")
        #expect(TimeText.timeOfDay(hour: 19, minute: 45, uses24Hour: false) == "7:45 PM")
    }

    @Test func timeUntil() {
        #expect(TimeText.until(20) == "in 1 minute")
        #expect(TimeText.until(0) == "in less than a minute")
        #expect(TimeText.until(3600) == "in 1 hour")
        #expect(TimeText.until(7 * 3600 + 300) == "in 7 hours 5 minutes")
        #expect(TimeText.until(2 * 86_400 + 3600) == "in 2 days 1 hour")
    }

    @Test func offsets() {
        #expect(TimeText.offset(0) == "Same time")
        #expect(TimeText.offset(3 * 3600) == "3 hours ahead")
        #expect(TimeText.offset(-3600) == "1 hour behind")
        #expect(TimeText.offset(-(5 * 3600 + 1800)) == "5 hours 30 minutes behind")
        #expect(TimeText.offset(45 * 60) == "45 minutes ahead")
    }

    @Test func days() {
        #expect(TimeText.day(0) == "Today")
        #expect(TimeText.day(1) == "Tomorrow")
        #expect(TimeText.day(-1) == "Yesterday")
        // Across the turn of a year.
        #expect(TimeText.day(-364) == "Tomorrow")
        #expect(TimeText.day(365) == "Yesterday")
    }

    @Test func placesFromTimeZones() {
        #expect(TimeText.city("America/New_York") == "New York")
        #expect(TimeText.city("America/Indiana/Indianapolis") == "Indianapolis")
        #expect(TimeText.city("UTC") == "UTC")
        #expect(TimeText.region("America/New_York") == "America")
        #expect(TimeText.region("UTC") == "")
    }
}

@Suite struct ChimeTests {

    @Test func aRoundIsFourBeepsAndAPause() {
        let samples = Chime.samples(sampleRate: 1000)
        // Four beeps of 100 and gaps of 80, then 600 of quiet.
        #expect(samples.count == 4 * 180 + 600)
        #expect(samples.suffix(600).allSatisfy { $0 == 0 })
        #expect(samples[100..<180].allSatisfy { $0 == 0 })
        #expect(samples[0..<100].contains { $0 != 0 })
        let loudest = samples.map { abs(Int($0)) }.max() ?? 0
        #expect(loudest <= 9000)
    }

    @Test func theWAVHasAHeaderAndEverySample() {
        let wav = Chime.wav(sampleRate: 1000)
        #expect(Array(wav[0..<4]) == Array("RIFF".utf8))
        #expect(Array(wav[8..<12]) == Array("WAVE".utf8))
        #expect(wav.count == 44 + 2 * Chime.samples(sampleRate: 1000).count)
        // The rate, in four bytes from the least.
        #expect(Array(wav[24..<28]) == [0xE8, 0x03, 0, 0])
    }
}
