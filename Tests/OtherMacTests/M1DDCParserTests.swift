import Testing

@testable import OtherMac

struct M1DDCParserTests {
  @Test
  func parsesTheFormatUsedByTheWorkingElectronApp() {
    let output = """
      [1] DELL U3223QE (7406FFA1-7562-4A2F-B764-55FAA7E45CCF)
      [2] Studio Display (ABCDEF00-1111-2222-3333-444455556666)
      """

    let displays = M1DDCParser.parseDisplays(output)

    #expect(
      displays == [
        DetectedDisplay(
          index: 1,
          name: "DELL U3223QE",
          uuid: "7406FFA1-7562-4A2F-B764-55FAA7E45CCF"
        ),
        DetectedDisplay(
          index: 2,
          name: "Studio Display",
          uuid: "ABCDEF00-1111-2222-3333-444455556666"
        ),
      ])
  }

  @Test
  func ignoresUnrelatedOutputWithoutLosingValidDisplays() {
    let output = """
      warning: transient probe message
      [1] DELL U3223QE (7406FFA1-7562-4A2F-B764-55FAA7E45CCF)

      """

    let displays = M1DDCParser.parseDisplays(output)

    #expect(displays.count == 1)
    #expect(displays.first?.index == 1)
  }
}
