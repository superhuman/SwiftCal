//
//  ICSTimeZoneParser.swift
//  CalendarKit-Swift
//
//  Created by Sanket Firodiya on 12/8/20.
//  Copyright © 2020 Maurice Arikoglu. All rights reserved.
//

import Foundation

internal struct ICSEventKey {
    static let exceptionDate = "EXDATE;"
    static let exceptionRule = "EXRULE:"
    static let recurrenceRule = "RRULE:"
    static let transparent = "TRANSP:"
    static let summary = "SUMMARY:"
    static let status = "STATUS:"
    static let organizer = "ORGANIZER;"
    static let organizer2 = "ORGANIZER:"
    static let sequence = "SEQUENCE:"
    static let location = "LOCATION:"
    static let lastModified = "LAST-MODIFIED:"
    static let description = "DESCRIPTION:"
    static let description2 = "DESCRIPTION;"
    static let created = "CREATED:"
    static let recurrenceId = "RECURRENCE-ID;TZID=%@"
    static let attendee = "ATTENDEE;"
    static let uniqueId = "UID:"
    static let timestamp = "DTSTAMP:"
    static let endDate = "DTEND:"
    static let endDateValueDate = "DTEND;VALUE=DATE:"
    static let endDateAndTimezone = "DTEND;TZID=%@:"
    static let startDate = "DTSTART:"
    static let startDateValueDate = "DTSTART;VALUE=DATE:"
    static let startDateAndTimezone = "DTSTART;TZID=%@:"
    static let timezone = "TZID:"
    static let timezoneStartDateAndTimezone = "DTSTART;TZID="
    static let timezoneBegin = "BEGIN:VTIMEZONE"
    static let timezoneEnd = "END:VTIMEZONE"
    static let eventBegin = "BEGIN:VEVENT"
    static let eventEnd = "END:VEVENT"
    static let daylightBegin = "BEGIN:DAYLIGHT"
    static let daylightEnd = "END:DAYLIGHT"
    static let standardBegin = "BEGIN:STANDARD"
    static let standardEnd = "END:STANDARD"
    static let timezoneOffsetTo = "TZOFFSETTO:"
    static let timezoneOffsetFrom = "TZOFFSETFROM:"
    static let timezoneName = "TZNAME:"
}

struct ICSTimeZoneParser {

    public static func timeZoneIdentifier(from icsString: String) -> String? {
        var timezoneNSString: NSString?
        var timezoneString: String?

        var eventScanner = Scanner(string: icsString)
        eventScanner.scanUpTo(ICSEventKey.timezoneStartDateAndTimezone, into: nil)
        eventScanner.scanUpTo(":", into: &timezoneNSString)

        // Handle variations of timezone:
        //   - `DTSTART;TZID="(UTC-05:00) Eastern Time (US & Canada)":20180320T133000` (has ":" in tzid)
        //   - `DTSTART;TZID=Arabian Standard Time:20180225T110000`
        eventScanner.scanString(":", into: nil)
        var partialTimezoneString: NSString?
        var tempString: NSString?

        let cachedScanLocation = eventScanner.scanLocation
        eventScanner.scanUpTo("\n", into: &tempString)

        if let tempString = tempString, tempString.contains(":") {
            eventScanner.scanLocation = cachedScanLocation
            eventScanner.scanUpTo(":", into: &partialTimezoneString)
            timezoneNSString = timezoneNSString?.appendingFormat(":%@", partialTimezoneString!)
        }

        timezoneString = timezoneNSString?.replacingOccurrences(of: ICSEventKey.timezoneStartDateAndTimezone, with: "").trimmingCharacters(in: CharacterSet.newlines).fixIllegalICS()

        if timezoneString == nil {

            eventScanner = Scanner(string: icsString)
            eventScanner.scanUpTo(ICSEventKey.timezone, into: nil)
            eventScanner.scanUpTo("\n", into: &timezoneNSString)

            timezoneString = timezoneNSString?.replacingOccurrences(of: ICSEventKey.timezone, with: "").trimmingCharacters(in: CharacterSet.newlines).fixIllegalICS()

        }

        return timezoneString
    }

    public static func timeZoneTimes(from icsString: String) -> (daylightSavings: TimeZoneTime, standard: TimeZoneTime)? {

        var daylightNSString: NSString?
        /*
         BEGIN:DAYLIGHT
         TZOFFSETFROM:+0100
         TZOFFSETTO:+0200
         TZNAME:CEST
         DTSTART:19700329T020000
         RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU
         END:DAYLIGHT
         */
        let daylightScanner = Scanner(string: icsString)
        daylightScanner.scanUpTo(ICSEventKey.daylightBegin, into: nil)
        daylightScanner.scanUpTo(ICSEventKey.daylightEnd, into: &daylightNSString)

        var standardNSString: NSString?
        /*
         BEGIN:STANDARD
         TZOFFSETFROM:+0200
         TZOFFSETTO:+0100
         TZNAME:CET
         DTSTART:19701025T030000
         RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU
         END:STANDARD
         */
        let standardScanner = Scanner(string: icsString)
        standardScanner.scanUpTo(ICSEventKey.standardBegin, into: nil)
        standardScanner.scanUpTo(ICSEventKey.standardEnd, into: &standardNSString)

        guard let daylightInfo = daylightNSString, let standardInfo = standardNSString else {
            return nil
        }

        guard let daylightTime = timeZoneTime(from: String(daylightInfo), daylightSaving: true),
              let standardTime = timeZoneTime(from: String(standardInfo), daylightSaving: false) else {
            return nil
        }

        return (daylightTime, standardTime)
    }

    private static func timeZoneTime(from icsString: String, daylightSaving: Bool) -> TimeZoneTime? {
        var timezone = TimeZoneTime(daylightSaving: daylightSaving)
        let timezoneName = timeZoneName(from: icsString) ?? ""

        guard let offsetFromString = timeZoneOffsetFrom(from: icsString),
              let offsetToString = timeZoneOffsetTo(from: icsString),
              offsetFromString.count == 5 && offsetToString.count == 5,
              let startDateString = ICSEventParser.startDate(from: icsString, timezone: nil),
              let firstCharacterFrom = offsetFromString.first,
              let firstCharacterTo = offsetToString.first,
              firstCharacterFrom == "+" || firstCharacterFrom == "-",
              firstCharacterTo == "+" || firstCharacterTo == "-",
              let startDate = DateFormatter().dateFromICSString(icsDate: startDateString).date else {
            return nil
        }

        guard let hoursFrom = Int(offsetFromString.dropFirst().dropLast(2)),
              let minutesFrom = Int(offsetFromString.dropFirst(3)),
              let hoursTo = Int(offsetToString.dropFirst().dropLast(2)),
              let minutesTo = Int(offsetToString.dropFirst(3)) else {
            return nil
        }

        let isToAhead = offsetToString.first == "+"
        let isFromAhead = offsetFromString.first == "+"

        timezone.name = timezoneName
        timezone.startDate = startDate
        timezone.offsetFrom = ((hoursFrom * 60 * 60) + (minutesFrom * 60)) * (isFromAhead ? 1 : -1)
        timezone.offsetTo = ((hoursTo * 60 * 60) + (minutesTo * 60)) * (isToAhead ? 1 : -1)
        if let rrule = ICSEventParser.recurrenceRule(from: icsString) {
            timezone.rrule = ICSEventParser.eventRule(from: rrule)
        }

        return timezone
    }

    private static func timeZoneOffsetFrom(from icsString: String) -> String? {
        var offsetString: NSString?
        let eventScanner = Scanner(string: icsString)
        eventScanner.scanUpTo(ICSEventKey.timezoneOffsetFrom, into: nil)
        eventScanner.scanUpTo("\n", into: &offsetString)
        return offsetString?.replacingOccurrences(of: ICSEventKey.timezoneOffsetFrom, with: "").trimmingCharacters(in: CharacterSet.newlines).fixIllegalICS()
    }

    private static func timeZoneOffsetTo(from icsString: String) -> String? {
        var offsetString: NSString?
        let eventScanner = Scanner(string: icsString)
        eventScanner.scanUpTo(ICSEventKey.timezoneOffsetTo, into: nil)
        eventScanner.scanUpTo("\n", into: &offsetString)
        return offsetString?.replacingOccurrences(of: ICSEventKey.timezoneOffsetTo, with: "").trimmingCharacters(in: CharacterSet.newlines).fixIllegalICS()
    }

    private static func timeZoneName(from icsString: String) -> String? {
        var nameString: NSString?
        let eventScanner = Scanner(string: icsString)
        eventScanner.scanUpTo(ICSEventKey.timezoneName, into: nil)
        eventScanner.scanUpTo("\n", into: &nameString)
        return nameString?.replacingOccurrences(of: ICSEventKey.timezoneName, with: "").trimmingCharacters(in: CharacterSet.newlines).fixIllegalICS()
    }

}
