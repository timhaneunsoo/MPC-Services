//
//  MessiahPresbyterianServicesTests.swift
//  MessiahPresbyterianServicesTests
//
//  Created by Tim Han on 12/2/24.
//

import Testing
import SwiftUI
@testable import MessiahPresbyterianServices

struct MessiahPresbyterianServicesTests {
    @Test func testCalendarDefaultDateUpdate() async throws {
        // Create test dates for our scenario
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        let dec17Late = dateFormatter.date(from: "2024-12-17 23:59")!
        let dec18Early = dateFormatter.date(from: "2024-12-18 00:00")!
        
        // Simulate first app launch at 11:59 PM Dec 17
        var currentTestDate = dec17Late
        let view = await ScheduleView(orgId: "test") { currentTestDate }
        
        // Verify initial date is Dec 17
        #expect(
            Calendar.current.startOfDay(for: await view.currentDate()) ==
            Calendar.current.startOfDay(for: dec17Late),
            "Calendar should show December 17 initially"
        )
        
        // Simulate app relaunch at 12:00 AM Dec 18
        currentTestDate = dec18Early
        let newView = await ScheduleView(orgId: "test") { currentTestDate }
        
        // Verify date updated to Dec 18
        #expect(
            Calendar.current.startOfDay(for: await view.currentDate()) ==
            Calendar.current.startOfDay(for: dec18Early),
            "Calendar should show December 18 after midnight"
        )
    }
}
