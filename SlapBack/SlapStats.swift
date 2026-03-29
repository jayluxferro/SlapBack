import Foundation
import UserNotifications

final class SlapStats: ObservableObject {
    @Published var sessionSlaps: Int = 0
    @Published var sessionMaxCombo: Int = 0
    @Published var sessionHardestHit: Double = 0

    @Published var allTimeSlaps: Int {
        didSet { UserDefaults.standard.set(allTimeSlaps, forKey: "stats.allTimeSlaps") }
    }
    @Published var allTimeMaxCombo: Int {
        didSet { UserDefaults.standard.set(allTimeMaxCombo, forKey: "stats.allTimeMaxCombo") }
    }
    @Published var allTimeHardestHit: Double {
        didSet { UserDefaults.standard.set(allTimeHardestHit, forKey: "stats.allTimeHardestHit") }
    }
    @Published var allTimeSessions: Int {
        didSet { UserDefaults.standard.set(allTimeSessions, forKey: "stats.allTimeSessions") }
    }

    var notificationsEnabled: Bool = true

    // Milestones to notify at
    private let slapMilestones: Set<Int> = [10, 50, 100, 250, 500, 1000, 5000, 10000]
    private var notifiedComboRecord = false

    private var sessionCounted = false

    init() {
        let ud = UserDefaults.standard
        allTimeSlaps = ud.integer(forKey: "stats.allTimeSlaps")
        allTimeMaxCombo = ud.integer(forKey: "stats.allTimeMaxCombo")
        allTimeHardestHit = ud.double(forKey: "stats.allTimeHardestHit")
        allTimeSessions = ud.integer(forKey: "stats.allTimeSessions")
        requestNotificationPermission()
    }

    func recordSlap(magnitude: Double) {
        if !sessionCounted { sessionCounted = true; allTimeSessions += 1 }
        sessionSlaps += 1
        allTimeSlaps += 1
        if magnitude > sessionHardestHit { sessionHardestHit = magnitude }
        if magnitude > allTimeHardestHit { allTimeHardestHit = magnitude }

        // Milestone notifications
        if notificationsEnabled && slapMilestones.contains(allTimeSlaps) {
            sendNotification(title: "Milestone!", body: "\(allTimeSlaps) total slaps! Keep it up.")
        }
    }

    func recordCombo(_ count: Int) {
        if count > sessionMaxCombo { sessionMaxCombo = count }
        if count > allTimeMaxCombo {
            allTimeMaxCombo = count
            if notificationsEnabled && !notifiedComboRecord && count >= 3 {
                notifiedComboRecord = true
                sendNotification(title: "New Combo Record!", body: "\(count)x combo — your best ever!")
            }
        }
    }

    func resetAllTime() {
        allTimeSlaps = 0; allTimeMaxCombo = 0; allTimeHardestHit = 0; allTimeSessions = 1
        notifiedComboRecord = false
    }

    func exportText() -> String {
"""
SlapBack Stats
==============
Session: \(sessionSlaps) slaps, \(sessionMaxCombo)x max combo, \(String(format: "%.2fg", sessionHardestHit)) hardest
All-Time: \(allTimeSlaps) slaps, \(allTimeMaxCombo)x best combo, \(String(format: "%.2fg", allTimeHardestHit)) hardest, \(allTimeSessions) sessions
"""
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
