import AppKit
import SwiftUI

enum DroppieTheme {
  static let popoverWidth: CGFloat = 336
  static var maxPopoverHeight: CGFloat {
    let visibleHeight = NSScreen.main?.visibleFrame.height ?? 900
    return floor(visibleHeight * 0.8)
  }

  static var maxHistoryListHeight: CGFloat {
    max(180, maxPopoverHeight - 166)
  }

  static let success = Color(hex: "30D158")
  static let warning = Color(hex: "FF9F0A")
  static let danger = Color(hex: "FF453A")
  static let neutral = Color(hex: "8E8E93")

  static let rowHover = Color.primary.opacity(0.06)
  static let controlFill = Color.primary.opacity(0.06)
  static let actionFill = Color.primary.opacity(0.085)
  static let selectedFill = Color.primary.opacity(0.15)
  static let divider = Color.primary.opacity(0.12)

  static let controlRadius: CGFloat = 8
  static let chipRadius: CGFloat = 6
}

extension Color {
  init(hex: String) {
    let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var integer: UInt64 = 0
    Scanner(string: value).scanHexInt64(&integer)

    let red: UInt64
    let green: UInt64
    let blue: UInt64
    let alpha: UInt64

    switch value.count {
    case 8:
      red = (integer >> 24) & 0xff
      green = (integer >> 16) & 0xff
      blue = (integer >> 8) & 0xff
      alpha = integer & 0xff
    default:
      red = (integer >> 16) & 0xff
      green = (integer >> 8) & 0xff
      blue = integer & 0xff
      alpha = 0xff
    }

    self.init(
      .sRGB,
      red: Double(red) / 255,
      green: Double(green) / 255,
      blue: Double(blue) / 255,
      opacity: Double(alpha) / 255
    )
  }
}
