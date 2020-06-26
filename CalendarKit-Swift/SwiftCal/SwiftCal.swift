//
//  SwiftCal.swift
//  CalendarKit-Swift
//
//  Created by Maurice Arikoglu on 30.11.17.
//  Copyright © 2017 Maurice Arikoglu. All rights reserved.
//

import UIKit

public class SwiftCal: NSObject {

    public var events = [CalendarEvent]()
    public var method: String?
    public var timezone: TimeZone?
    
    @discardableResult public func addEvent(_ event: CalendarEvent) -> Int {
        
        events.append(event)
        return events.count
    }
    
    public func events(for date: Date) -> [CalendarEvent] {
        
        var eventsForDate = [CalendarEvent]()
        
        for event in events {
            if event.takesPlaceOnDate(date) { eventsForDate.append(event) }
        }
        
        eventsForDate = eventsForDate.sorted(by: { (e1, e2) in
            //We compare time only because initial start dates might be different because of recurrence
            let calendar = Calendar.current
            guard let sd1 = e1.startDate,
                let sd2 = e2.startDate,
            let compareDate1 = calendar.date(from: calendar.dateComponents([.hour, .minute, .second], from: sd1)),
            let compareDate2 = calendar.date(from: calendar.dateComponents([.hour, .minute, .second], from: sd2))
                else { return false }
            
            return compareDate1 < compareDate2
        })
        
        return eventsForDate
    }
    
}

public class Read {

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

    public static func swiftCal(from icsString: String) -> SwiftCal {

        let formattedICS = icsString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var calendarEvents = formattedICS.components(separatedBy: "BEGIN:VEVENT")

        var timezoneString: NSString?
        let timezoneScanner = Scanner(string: icsString)
        timezoneScanner.scanUpTo("BEGIN:VTIMEZONE", into: nil)
        timezoneScanner.scanUpTo("END:VTIMEZONE", into: &timezoneString)

        let calendar = SwiftCal()

        if calendarEvents.count > 0 {

            var methodString: NSString?
            let methodScanner = Scanner(string: icsString)
            methodScanner.scanUpTo("METHOD:", into: nil)
            methodScanner.scanUpTo("\r\n", into: &methodString)
            if let theMethodString = methodString {
                calendar.method = String(theMethodString.substring(from: 7))
            }

            var timezoneId: NSString?
            var timezoneOffset: NSString?

            let headerScanner = Scanner(string: calendarEvents.first!)
            headerScanner.scanUpTo("TZID:", into: nil)
            headerScanner.scanUpTo("\n", into: &timezoneId)
            headerScanner.scanUpTo("BEGIN:STANDARD", into: nil)
            headerScanner.scanUpTo("TZOFFSETTO:", into: nil)
            headerScanner.scanUpTo("\n", into: &timezoneOffset)

            if let timezoneId = timezoneId?.replacingOccurrences(of: "TZID:", with: "").trimmingCharacters(in: .newlines) {
                if let timezone = TimeZone(identifier: timezoneId) {
                    calendar.timezone = timezone
                } else if let timezone = TimeZone(abbreviation: timezoneId) {
                    calendar.timezone = timezone
                } else if let timezone = translateFromWindowsTimezone(tzid: timezoneId) {
                    calendar.timezone = TimeZone(identifier: timezone)
                } else if let timezoneOffset = timezoneOffset?.replacingOccurrences(of: "TZOFFSETTO:", with: "").trimmingCharacters(in: .newlines) {
                    // timezoneoffset e.g. +0430 indicating 4 hours 30 mins ahead of UTC
                    if timezoneOffset.count == 5 {
                        let isAhead = timezoneOffset.first == "+"
                        let hoursString = timezoneOffset.dropFirst().dropLast(2)
                        let minutesString = timezoneOffset.dropFirst(3)
                        if let hours = Int(hoursString), let minutes = Int(minutesString) {
                            let offset = hours * 60 * 60 + minutes * 60
                            let offsetFromUTC = isAhead ? offset : -offset
                            calendar.timezone = TimeZone(secondsFromGMT: Int(offsetFromUTC))
                        }
                    }
                }
            }

            calendarEvents.remove(at: 0)
        }

        for event in calendarEvents {

            guard let calendarEvent = ICSEventParser.event(from: event, calendarTimezone: calendar.timezone) else { continue }
            calendar.addEvent(calendarEvent)
        }

        return calendar
    }
}

