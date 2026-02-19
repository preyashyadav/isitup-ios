//
//  NotificationGrouper.swift
//  isitup
//
//  Created by Preyash Yadav on 2/19/26.
//

import Foundation

struct GroupedOutageDecision {
  let shouldSendGroupedNotification: Bool
}

protocol NotificationGrouping: AnyObject {
  func decide(newlyFailedServices: [ServiceStatus]) -> GroupedOutageDecision
}

final class NotificationGrouper: NotificationGrouping {
  func decide(newlyFailedServices: [ServiceStatus]) -> GroupedOutageDecision {
    GroupedOutageDecision(shouldSendGroupedNotification: newlyFailedServices.count >= 2)
  }
}
