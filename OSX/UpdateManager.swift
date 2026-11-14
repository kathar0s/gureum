//
//  UpdateManager.swift
//  OSX
//
//  Created by Jeong YunWon on 01/01/2019.
//  Copyright © 2019 youknowone.org. All rights reserved.
//

import Alamofire
import Foundation
import GureumCore

class UpdateManager {
  static let shared = UpdateManager()

  struct UpdateInfo: Decodable {
    let version: String
    let description: String
    let url: String

    enum CodingKeys: String, CodingKey {
      case version
      case description
      case url
    }
  }

  struct VersionInfo {
    let current: String? = Bundle.main.version
    let update: UpdateInfo
    let experimental: Bool
  }

  static func feedURL(
    mode: UpdateMode, identity: InputMethodIdentity = .current
  ) -> URL? {
    guard identity.supportsUpdates else { return nil }
    switch (identity.productKind, mode) {
    case (.upstream, .stable):
      return URL(string: "https://gureum.io/version.json")
    case (.upstream, .experimental):
      return URL(string: "https://gureum.io/version-experimental.json")
    case (.baram, .stable):
      return URL(string: "https://baram.sionyuel.com/version.json")
    case (.baram, .experimental), (.lab, _):
      return nil
    }
  }

  static func shouldOffer(updateVersion: String, currentVersion: String?) -> Bool {
    guard let currentVersion else { return true }
    guard let update = parsedVersion(updateVersion), let current = parsedVersion(currentVersion)
    else { return false }
    for index in 0..<max(update.numbers.count, current.numbers.count) {
      let updatePart = index < update.numbers.count ? update.numbers[index] : 0
      let currentPart = index < current.numbers.count ? current.numbers[index] : 0
      if updatePart != currentPart { return updatePart > currentPart }
    }
    switch (update.prerelease, current.prerelease) {
    case (nil, nil):
      return false
    case (nil, _?):
      return true
    case (_?, nil):
      return false
    case (.some(let updatePrerelease), .some(let currentPrerelease)):
      if updatePrerelease.name != currentPrerelease.name {
        return updatePrerelease.name > currentPrerelease.name
      }
      return updatePrerelease.number > currentPrerelease.number
    }
  }

  private struct ParsedVersion {
    let numbers: [Int]
    let prerelease: (name: String, number: Int)?
  }

  private static func parsedVersion(_ value: String) -> ParsedVersion? {
    guard let start = value.firstIndex(where: { $0.isNumber }) else { return nil }
    let numeric = value[start...].prefix { $0.isNumber || $0 == "." }
    let parts = numeric.split(separator: ".", omittingEmptySubsequences: false)
    guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && Int($0) != nil }) else { return nil }
    let numbers = parts.compactMap { Int($0) }
    let suffixStart = value.index(start, offsetBy: numeric.count)
    let suffix = value[suffixStart...].drop(while: { $0 == "-" })
    guard let firstToken = suffix.split(separator: "-").first else {
      return ParsedVersion(numbers: numbers, prerelease: nil)
    }
    let token = firstToken.lowercased()
    if token == "debug" || Int(token) != nil {
      return ParsedVersion(numbers: numbers, prerelease: nil)
    }
    let name = String(token.prefix(while: { $0.isLetter }))
    let numberText = token.dropFirst(name.count)
    let number = Int(numberText) ?? 0
    return ParsedVersion(numbers: numbers, prerelease: (name, number))
  }

  func requestVersionInfo(mode: UpdateMode, _ done: @escaping ((VersionInfo?) -> Void)) {
    guard let url = Self.feedURL(mode: mode) else {
      done(nil)
      return
    }
    var urlRequest = URLRequest(url: url)
    urlRequest.timeoutInterval = 1.0
    urlRequest.cachePolicy = .reloadIgnoringCacheData

    let request = AF.request(urlRequest)
    //        request.responseJSON {
    //            data in
    //            print("data!", data)
    //        }
    request.validate().responseDecodable(of: UpdateInfo.self) { response in
      guard let update = response.value else { return done(nil) }
      let version = VersionInfo(update: update, experimental: mode == .experimental)
      done(version)
    }
  }

  func requestAutoUpdateVersionInfo(_ done: @escaping ((VersionInfo?) -> Void)) {
    guard Configuration.shared.updateNotification else {
      return
    }
    let mode: UpdateMode =
      InputMethodIdentity.current.supportsExperimentalUpdates
      ? (Configuration.shared.updateMode ?? .stable) : .stable
    requestVersionInfo(mode: mode, done)
  }

  class func notifyUpdate(info: VersionInfo) {
    let notification = NSUserNotification()
    let displayName =
      (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
      ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
      ?? "구름 입력기"
    var title = "\(displayName) 업데이트 알림"
    if info.experimental {
      title += " (실험 버전)"
    }
    notification.title = title
    notification.hasActionButton = true
    notification.hasReplyButton = false
    notification.actionButtonTitle = "업데이트"
    notification.otherButtonTitle = "취소"
    notification.informativeText =
      "최신 버전: \(info.update.version) 현재 버전: \(info.current ?? "-")\n\(info.update.description)"
    notification.userInfo = ["url": info.update.url]

    NSUserNotificationCenter.default.deliver(notification)
  }

  func notifyUpdateIfNeeded() {
    requestAutoUpdateVersionInfo { info in
      guard let info = info else {
        return
      }
      guard Self.shouldOffer(updateVersion: info.update.version, currentVersion: info.current)
      else {
        return
      }
      UpdateManager.notifyUpdate(info: info)
    }
  }
}
