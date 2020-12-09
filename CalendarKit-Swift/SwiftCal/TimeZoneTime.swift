//
//  TimeZoneTime.swift
//  CalendarKit-Swift
//
//  Created by Sanket Firodiya on 12/8/20.
//  Copyright © 2020 Maurice Arikoglu. All rights reserved.
//

import Foundation
/*

 BEGIN:VTIMEZONE
 TZID:Europe/Berlin
 X-LIC-LOCATION:Europe/Berlin
 BEGIN:DAYLIGHT
 TZOFFSETFROM:+0100
 TZOFFSETTO:+0200
 TZNAME:CEST
 DTSTART:19700329T020000
 RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU
 END:DAYLIGHT
 BEGIN:STANDARD
 TZOFFSETFROM:+0200
 TZOFFSETTO:+0100
 TZNAME:CET
 DTSTART:19701025T030000
 RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU
 END:STANDARD
 END:VTIMEZONE
 */

internal struct TimeZoneTime {
    var isDaylightSaving: Bool
    var startDate: Date!
    var name: String!
    var rrule: EventRule?

    var offsetFrom: Int
    var offsetTo: Int

    init(daylightSaving: Bool) {
        self.isDaylightSaving = daylightSaving
        self.offsetTo = 0
        self.offsetFrom = 0
    }
}

internal enum TimeZoneError: Error {
    case missingTimeZoneInfo
    case missingTimeZoneTimeInfo
    case missingTimeZoneId
    case invalidTimeZoneId
}

private enum GregorianCalendarWeek: Int {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    func icsIdentifier() -> String {
        switch self.rawValue {
        case 1:
            return "SU"
        case 2:
            return "MO"
        case 3:
            return "TU"
        case 4:
            return "WE"
        case 5:
            return "TH"
        case 6:
            return "FR"
        case 7:
            return "SA"
        default:
            return ""
        }
    }

    static func fromICS(ics: String) -> GregorianCalendarWeek? {
        switch ics {
        case "SU":
            return .sunday
        case "MO":
            return .monday
        case "TU":
            return .tuesday
        case "WE":
            return .wednesday
        case "TH":
            return .thursday
        case "FR":
            return .friday
        case "SA":
            return .saturday
        default:
            return nil
        }
    }
}

extension TimeZone {
    public init?(formattedICS: String) throws {
        var timezoneNSString: NSString?
        let timezoneScanner = Scanner(string: formattedICS)
        timezoneScanner.scanUpTo(ICSEventKey.timezoneBegin, into: nil)
        timezoneScanner.scanUpTo(ICSEventKey.timezoneEnd, into: &timezoneNSString)

        guard let unwrappedTimezoneString = timezoneNSString else {
            throw TimeZoneError.missingTimeZoneInfo
        }

        let timezoneICS = String(unwrappedTimezoneString)

        if let timeZoneIdentifier = ICSTimeZoneParser.timeZoneIdentifier(from: timezoneICS),
           let timezone = TimeZone(identifier: timeZoneIdentifier) {
            self = timezone
            return
        }

        if let timeZoneIdentifier = ICSTimeZoneParser.timeZoneIdentifier(from: timezoneICS),
           let timeZoneId = Self.translateFromWindowsTimezone(tzid: timeZoneIdentifier),
           let timeZone = TimeZone(identifier: timeZoneId) {
            self = timeZone
            return
        }

        let timeZoneTimes = ICSTimeZoneParser.timeZoneTimes(from: timezoneICS)
        guard let daylightTime = timeZoneTimes?.daylightSavings,
              let standardTime = timeZoneTimes?.standard else {
            throw TimeZoneError.missingTimeZoneId
        }

        guard let timezone = TimeZone(formattedICS: formattedICS, daylightTime: daylightTime, standardTime: standardTime) else {
            throw TimeZoneError.missingTimeZoneTimeInfo
        }

        self = timezone
        return
    }

    init?(formattedICS: String, daylightTime: TimeZoneTime, standardTime: TimeZoneTime) {
        let eventDate: Date
        if let date = ICSEventParser.startDate(from: formattedICS).date {
            eventDate = date
        } else {
            eventDate = Date()
        }

        guard let daylightMonthString = daylightTime.rrule?.byMonth?.first,
              let standardMonthString = standardTime.rrule?.byMonth?.first,
              let daylightMonth = Int(daylightMonthString),
              let standardMonth = Int(standardMonthString),
              let daylightDay = daylightTime.rrule?.byDay?.first,
              let standardDay = standardTime.rrule?.byDay?.first else {
            // we can determine whether the event date is during standard or daylight savings from rrule
            // if rrule is nil, return the standard time
            if let name = standardTime.name, let timezone = TimeZone(abbreviation: name) {
                self = timezone
            } else {
                self.init(secondsFromGMT: standardTime.offsetTo)
            }

            return
        }

        let daylightWeekDayString = String(daylightDay[daylightDay.index(daylightDay.endIndex, offsetBy: -2)...])
        let standardWeekDayString = String(standardDay[standardDay.index(standardDay.endIndex, offsetBy: -2)...])

        let daylightWeekDay = GregorianCalendarWeek.fromICS(ics: daylightWeekDayString)!.rawValue
        let standardWeekDay = GregorianCalendarWeek.fromICS(ics: standardWeekDayString)!.rawValue

        let prefixDaylight = String(daylightDay.dropLast(2))
        let prefixStandard = String(standardDay.dropLast(2))

        var daylightDate: Date!
        var standardDate: Date!

        let eventYear = Calendar.current.component(.year, from: eventDate)
        if prefixDaylight.count > 0 {
            let ordinalDaylight = Int(prefixDaylight)
            daylightDate = Date().set(month: daylightMonth, weekday: daylightWeekDay, year: eventYear, ordinal: ordinalDaylight)
        } else {
            daylightDate = Date().set(month: daylightMonth, weekday: daylightWeekDay, year: eventYear)
        }

        if prefixStandard.count > 0 {
            let ordinalStandard = Int(prefixStandard)
            standardDate = Date().set(month: standardMonth, weekday: standardWeekDay, year: eventYear, ordinal: ordinalStandard)
        } else {
            standardDate = Date().set(month: standardMonth, weekday: standardWeekDay, year: eventYear)
        }

        if daylightDate < standardDate {
            // Daylight date is earlier in year than standard date
            if (daylightDate...standardDate).contains(eventDate) {
                // Current Date is in daylight saving time
                guard let name = daylightTime.name, let timezone = TimeZone(abbreviation: name) else {
                    self.init(secondsFromGMT: daylightTime.offsetTo)
                    return
                }

                self = timezone
                return
            } else {
                guard let name = standardTime.name, let timezone = TimeZone(abbreviation: name) else {
                    self.init(secondsFromGMT: standardTime.offsetTo)
                    return
                }

                self = timezone
                return
            }
        } else {
            if (standardDate...daylightDate).contains(eventDate) {
                guard let name = standardTime.name, let timezone = TimeZone(abbreviation: name) else {
                    self.init(secondsFromGMT: standardTime.offsetTo)
                    return
                }

                self = timezone
                return
            } else {
                // Current Date is in daylight saving time
                guard let name = daylightTime.name, let timezone = TimeZone(abbreviation: name) else {
                    self.init(secondsFromGMT: daylightTime.offsetTo)
                    return
                }

                self = timezone
                return
            }
        }
    }

    // https://stackoverflow.com/a/25280376/1917852
    private static func translateFromWindowsTimezone(tzid: String) -> String? {
        let timezoneDictionary = [
            "AUS Central Standard Time": "Australia/Darwin",
            "Afghanistan Standard Time": "Asia/Kabul",
            "Alaskan Standard Time": "America/Anchorage",
            "Arab Standard Time": "Asia/Riyadh",
            "Arabic Standard Time": "Asia/Baghdad",
            "Argentina Standard Time": "America/Buenos_Aires",
            "Atlantic Standard Time": "America/Halifax",
            "Azerbaijan Standard Time": "Asia/Baku",
            "Azores Standard Time": "Atlantic/Azores",
            "Bahia Standard Time": "America/Bahia",
            "Bangladesh Standard Time": "Asia/Dhaka",
            "Canada Central Standard Time": "America/Regina",
            "Cape Verde Standard Time": "Atlantic/Cape_Verde",
            "Caucasus Standard Time": "Asia/Yerevan",
            "Cen. Australia Standard Time": "Australia/Adelaide",
            "Central America Standard Time": "America/Guatemala",
            "Central Asia Standard Time": "Asia/Almaty",
            "Central Brazilian Standard Time": "America/Cuiaba",
            "Central Europe Standard Time": "Europe/Budapest",
            "Central European Standard Time": "Europe/Warsaw",
            "Central Pacific Standard Time": "Pacific/Guadalcanal",
            "Central Standard Time": "America/Chicago",
            "Central Standard Time (Mexico)": "America/Mexico_City",
            "China Standard Time": "Asia/Shanghai",
            "Dateline Standard Time": "Etc/GMT+12",
            "E. Africa Standard Time": "Africa/Nairobi",
            "E. Australia Standard Time": "Australia/Brisbane",
            "E. Europe Standard Time": "Asia/Nicosia",
            "E. South America Standard Time": "America/Sao_Paulo",
            "Eastern Standard Time": "America/New_York",
            "Egypt Standard Time": "Africa/Cairo",
            "Ekaterinburg Standard Time": "Asia/Yekaterinburg",
            "FLE Standard Time": "Europe/Kiev",
            "Fiji Standard Time": "Pacific/Fiji",
            "GMT Standard Time": "Europe/London",
            "GTB Standard Time": "Europe/Bucharest",
            "Georgian Standard Time": "Asia/Tbilisi",
            "Greenland Standard Time": "America/Godthab",
            "Greenwich Standard Time": "Atlantic/Reykjavik",
            "Hawaiian Standard Time": "Pacific/Honolulu",
            "India Standard Time": "Asia/Calcutta",
            "Iran Standard Time": "Asia/Tehran",
            "Israel Standard Time": "Asia/Jerusalem",
            "Jordan Standard Time": "Asia/Amman",
            "Kaliningrad Standard Time": "Europe/Kaliningrad",
            "Korea Standard Time": "Asia/Seoul",
            "Mauritius Standard Time": "Indian/Mauritius",
            "Middle East Standard Time": "Asia/Beirut",
            "Montevideo Standard Time": "America/Montevideo",
            "Morocco Standard Time": "Africa/Casablanca",
            "Mountain Standard Time": "America/Denver",
            "Mountain Standard Time (Mexico)": "America/Chihuahua",
            "Myanmar Standard Time": "Asia/Rangoon",
            "N. Central Asia Standard Time": "Asia/Novosibirsk",
            "Namibia Standard Time": "Africa/Windhoek",
            "Nepal Standard Time": "Asia/Katmandu",
            "New Zealand Standard Time": "Pacific/Auckland",
            "Newfoundland Standard Time": "America/St_Johns",
            "North Asia East Standard Time": "Asia/Irkutsk",
            "North Asia Standard Time": "Asia/Krasnoyarsk",
            "Pacific SA Standard Time": "America/Santiago",
            "Pacific Standard Time": "America/Los_Angeles",
            "Pacific Standard Time (Mexico)": "America/Santa_Isabel",
            "Pakistan Standard Time": "Asia/Karachi",
            "Paraguay Standard Time": "America/Asuncion",
            "Romance Standard Time": "Europe/Paris",
            "Russian Standard Time": "Europe/Moscow",
            "SA Eastern Standard Time": "America/Cayenne",
            "SA Pacific Standard Time": "America/Bogota",
            "SA Western Standard Time": "America/La_Paz",
            "SE Asia Standard Time": "Asia/Bangkok",
            "Samoa Standard Time": "Pacific/Apia",
            "Singapore Standard Time": "Asia/Singapore",
            "South Africa Standard Time": "Africa/Johannesburg",
            "Sri Lanka Standard Time": "Asia/Colombo",
            "Syria Standard Time": "Asia/Damascus",
            "Taipei Standard Time": "Asia/Taipei",
            "Tasmania Standard Time": "Australia/Hobart",
            "Tokyo Standard Time": "Asia/Tokyo",
            "Tonga Standard Time": "Pacific/Tongatapu",
            "Turkey Standard Time": "Europe/Istanbul",
            "US Eastern Standard Time": "America/Indianapolis",
            "US Mountain Standard Time": "America/Phoenix",
            "UTC": "Etc/GMT",
            "UTC+12": "Etc/GMT-12",
            "UTC-02": "Etc/GMT+2",
            "UTC-11": "Etc/GMT+11",
            "Ulaanbaatar Standard Time": "Asia/Ulaanbaatar",
            "Venezuela Standard Time": "America/Caracas",
            "Vladivostok Standard Time": "Asia/Vladivostok",
            "W. Australia Standard Time": "Australia/Perth",
            "W. Central Africa Standard Time": "Africa/Lagos",
            "W. Europe Standard Time": "Europe/Berlin",
            "West Asia Standard Time": "Asia/Tashkent",
            "West Pacific Standard Time": "Pacific/Port_Moresby",
            "Yakutsk Standard Time": "Asia/Yakutsk"]

        return timezoneDictionary[tzid]
    }
}

extension Date {
    public func set(month: Int, weekday: Int, year: Int, ordinal: Int? = nil) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = ordinal

        guard let date = Calendar.current.date(from: components) else {
            return self
        }

        return date
    }
}
