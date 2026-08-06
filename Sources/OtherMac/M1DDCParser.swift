import Foundation

enum M1DDCParser {
  private static let displayLine = try! NSRegularExpression(
    pattern: #"^\[(\d+)]\s+(.+?)\s+\(([^)]+)\)$"#
  )

  static func parseDisplays(_ output: String) -> [DetectedDisplay] {
    output
      .split(whereSeparator: \.isNewline)
      .compactMap { parseDisplayLine(String($0)) }
  }

  private static func parseDisplayLine(_ line: String) -> DetectedDisplay? {
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    guard
      let match = displayLine.firstMatch(in: line, range: range),
      match.numberOfRanges == 4,
      let indexRange = Range(match.range(at: 1), in: line),
      let nameRange = Range(match.range(at: 2), in: line),
      let uuidRange = Range(match.range(at: 3), in: line),
      let index = Int(line[indexRange])
    else {
      return nil
    }

    return DetectedDisplay(
      index: index,
      name: String(line[nameRange]),
      uuid: String(line[uuidRange])
    )
  }
}
