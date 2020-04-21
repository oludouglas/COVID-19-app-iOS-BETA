//
//  BluetoothPermissionDeniedViewControllerTests.swift
//  CoLocateTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import XCTest
@testable import CoLocate

class BluetoothPermissionDeniedViewControllerTests: TestCase {

    func testCallsCompletionCallbackWhenAppBecomesActive() {
        let notificationCenter = NotificationCenter()
        let uiQueue = QueueDouble()
        let vc = BluetoothPermissionDeniedViewController.instantiate()
        var called = false
        vc.inject(notificationCenter: notificationCenter, uiQueue: uiQueue) {
            called = true
        }
        XCTAssertNotNil(vc.view)
        
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        
        XCTAssertTrue(called)
    }
}
