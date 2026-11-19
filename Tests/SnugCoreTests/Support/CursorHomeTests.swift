import CoreGraphics
import Testing
@testable import SnugCore

@Suite("指针落点 CursorHome")
struct CursorHomeTests {
    private let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let other = CGRect(x: 0, y: 0, width: 100, height: 100)

    @Test("指针在留下的屏上：不动")
    func staysOnKept() {
        #expect(CursorHome.landing(pointer: CGPoint(x: 100, y: 100), kept: [main], main: main) == nil)
    }

    @Test("指针落在要撤的屏上：挪到主屏中央（issue #29）")
    func leavesRemovedScreen() {
        #expect(CursorHome.landing(pointer: CGPoint(x: 1600, y: 30), kept: [main], main: main) == CGPoint(x: 756, y: 491))
    }

    @Test("主屏就是要撤的那块：挪到第一块留下的屏中央")
    func fallsBackToFirstKept() {
        #expect(CursorHome.landing(pointer: CGPoint(x: 1600, y: 30), kept: [other], main: .zero) == CGPoint(x: 50, y: 50))
    }

    @Test("一块屏都不剩：不挪")
    func nothingLeft() {
        #expect(CursorHome.landing(pointer: CGPoint(x: 1600, y: 30), kept: [], main: .zero) == nil)
    }
}
