//
//  NotificationManagerTests.swift
//  CoLocateTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import Foundation

import XCTest
import Firebase
@testable import CoLocate

class NotificationManagerTests: TestCase {

    override func setUp() {
        super.setUp()

        FirebaseAppDouble.configureCalled = false
    }

    func testConfigure() {
        let messaging = MessagingDouble()
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { messaging },
            userNotificationCenter: NotificationCenterDouble(),
            persistence: Persistence()
        )

        notificationManager.configure()

        XCTAssertTrue(FirebaseAppDouble.configureCalled)
    }
    
    func testPushTokenHandling() {
        let messaging = MessagingDouble()
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { messaging },
            userNotificationCenter: NotificationCenterDouble(),
            persistence: Persistence()
        )
        let delegate = PushNotificationManagerDelegateDouble()
        notificationManager.delegate = delegate

        notificationManager.configure()
        // Ugh, can't find a way to not pass a real Messaging here. Should be ok as long as the actual delegate method doesn't use it.
        messaging.delegate!.messaging?(Messaging.messaging(), didReceiveRegistrationToken: "12345")
        XCTAssertEqual("12345", notificationManager.pushToken)
        XCTAssertEqual("12345", delegate.userInfo?["pushToken"] as! String)
    }

    func testRequestAuthorization_success() {
        let notificationCenterDouble = NotificationCenterDouble()
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: notificationCenterDouble,
            persistence: Persistence()
        )

        var granted: Bool?
        var error: Error?
        notificationManager.requestAuthorization { result in
            switch result {
            case .success(let g): granted = g
            case .failure(let e): error = e
            }
        }

        notificationCenterDouble.requestAuthCompletionHandler!(true, nil)
        DispatchQueue.test.flush()

        XCTAssertTrue(granted!)
        XCTAssertNil(error)
    }
    
    func testHandleNotification_savesPotentialDiagnosis() {
        let persistence = Persistence()
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: NotificationCenterDouble(),
            persistence: persistence
        )
        
        notificationManager.handleNotification(userInfo: ["status" : "Potential"])
        
        XCTAssertEqual(persistence.diagnosis, .potential)
    }

    func testHandleNotification_sendsLocalNotificationWithPotentialStatus() {
        let persistence = Persistence()
        let notificationCenterDouble = NotificationCenterDouble()
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: notificationCenterDouble,
            persistence: persistence
        )

        notificationManager.handleNotification(userInfo: ["status" : "Potential"])

        XCTAssertNotNil(notificationCenterDouble.request)
    }
    
    func testHandleNotification_doesNotSaveOtherDiagnosis() {
        let persistence = Persistence()
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: NotificationCenterDouble(),
            persistence: persistence
        )
        
        notificationManager.handleNotification(userInfo: ["status" : "infected"])
        
        XCTAssertEqual(persistence.diagnosis, .unknown)
    }

    func testHandleNotification_doesNotSendLocalNotificationWhenStatusIsNotPotential() {
        let persistence = Persistence()
        let notificationCenterDouble = NotificationCenterDouble()
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: notificationCenterDouble,
            persistence: persistence
        )

        notificationManager.handleNotification(userInfo: ["status" : "infected"])

        XCTAssertNil(notificationCenterDouble.request)
    }
    
    func testHandleNotification_forwardsNonDiagnosisNotificationsToDelegate() {
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: NotificationCenterDouble(),
            persistence: Persistence()
        )
        let delegate = PushNotificationManagerDelegateDouble()
        notificationManager.delegate = delegate
        let userInfo = ["something" : "else"]
        
        notificationManager.handleNotification(userInfo: userInfo)
        XCTAssertEqual(delegate.userInfo?["something"] as? String, "else")
    }

    func testHandleNotification_foreGroundedLocalNotification() {
        let persistence = Persistence()
        let notificationCenterDouble = NotificationCenterDouble()
        let notificationManager = ConcretePushNotificationManager(
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: notificationCenterDouble,
            persistence: persistence
        )

        notificationManager.handleNotification(userInfo: [:])

        XCTAssertNil(notificationCenterDouble.request)
    }
}

private class FirebaseAppDouble: TestableFirebaseApp {
    static var configureCalled = false
    static func configure() {
        configureCalled = true
    }
}

private class MessagingDouble: TestableMessaging {
    weak var delegate: MessagingDelegate?
}

private class NotificationCenterDouble: UserNotificationCenter {

    weak var delegate: UNUserNotificationCenterDelegate?

    var options: UNAuthorizationOptions?
    var requestAuthCompletionHandler: ((Bool, Error?) -> Void)?
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
        self.options = options
        self.requestAuthCompletionHandler = completionHandler
    }

    var request: UNNotificationRequest?
    var addCompletionHandler: ((Error?) -> Void)?
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        self.request = request
        self.addCompletionHandler = completionHandler
    }

}

private class PushNotificationManagerDelegateDouble: PushNotificationManagerDelegate {

    var userInfo: [AnyHashable : Any]?

    func pushNotificationManager(_ pushNotificationManager: PushNotificationManager, didReceiveNotificationWithInfo userInfo: [AnyHashable : Any]) {
        self.userInfo = userInfo
    }

}
