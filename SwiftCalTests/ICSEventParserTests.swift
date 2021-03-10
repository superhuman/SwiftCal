//
//  ICSEventParserTests.swift
//  SwiftCalTests
//
//  Created by Kevin Nattinger on 10/9/20.
//  Copyright © 2020 Superhuman, Inc. All rights reserved.
//

import XCTest
@testable import SwiftCal

private func icsStringWithLine(_ line: String) -> String {
    return """
        UID:E87642FC-0526-4FF2-88B2-4DDAE14C6A76\r
        DTSTART;TZID=Pacific Standard Time:20201008T110000\r
        DTEND;TZID=Pacific Standard Time:20201008T114500\r
        \(line)\r
        END:VEVENT\r
        END:VCALENDAR\r
        """
}

class SwiftCalTests: XCTestCase {

    func testLocation() {
        let location = "This is where we shall meet"

        let icsLocation = icsStringWithLine("LOCATION:\(location)")
        let icsLocationEvent = ICSEventParser.event(from: icsLocation)
        XCTAssertEqual(icsLocationEvent?.location, location)

        let icsLocationWithParameters = icsStringWithLine("LOCATION;LANGUAGE=en-US:\(location)")
        let icsLocationWithParametersEvent = ICSEventParser.event(from: icsLocationWithParameters)
        XCTAssertEqual(icsLocationWithParametersEvent?.location, location)
    }
    
    func testNoEndDate() {
        let icsEventWithoutEnd = """
        UID:E87642FC-0526-4FF2-88B2-4DDAE14C6A76\r
        DTSTART;TZID=Pacific Standard Time:20201008T110000\r
        END:VEVENT\r
        END:VCALENDAR\r
        """
        
        let parsedEvent = ICSEventParser.event(from: icsEventWithoutEnd)
        
        XCTAssertNotNil(parsedEvent?.endDate)
        XCTAssertEqual(parsedEvent?.startDate, parsedEvent?.endDate)
    }
}
