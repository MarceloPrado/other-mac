import SwiftUI

enum OtherMacStyle {
  static let parchment = Color(
    red: 1.0,
    green: 0.973,
    blue: 0.91
  )
  static let ink = Color(
    red: 0.188,
    green: 0.161,
    blue: 0.129
  )
  static let coral = Color(
    red: 0.941,
    green: 0.392,
    blue: 0.286
  )
  static let coralShadow = Color(
    red: 0.72,
    green: 0.278,
    blue: 0.204
  )
  static let paper = Color.white.opacity(0.62)
  static let secondaryInk = ink.opacity(0.62)
}

struct EditorialTitle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .font(.system(size: 31, weight: .medium, design: .serif))
      .tracking(-0.7)
      .foregroundStyle(OtherMacStyle.ink)
  }
}
