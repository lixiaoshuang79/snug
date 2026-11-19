import Foundation
import Testing
@testable import SnugCore


@Suite("会话 SessionEpisode")
struct SessionEpisodeTests {
    @Test("重连窗口 15s")
    func window() { #expect(SessionEpisode.reconnectWindow == 15) }

    @Test("连入开始会话；断开后 15s 内再连入算同一会话，超过窗口会话结束")
    func lifecycle() {
        var e = SessionEpisode()
        #expect(!e.isActive)
        #expect(e.connected(at: at(0)) == .began)
        #expect(e.disconnected(at: at(10)) == .interrupted)
        #expect(e.isActive)
        #expect(e.advance(to: at(24.9)) == nil)
        #expect(e.connected(at: at(25)) == .resumed)   // 10 + 15 = 25，还在窗口内
        #expect(e.disconnected(at: at(30)) == .interrupted)
        #expect(e.advance(to: at(45)) == nil)
        #expect(e.advance(to: at(45.1)) == .ended)
        #expect(!e.isActive)
        #expect(e.connected(at: at(50)) == .began)
    }

    @Test("重连窗口里点「立即结束」：当场结束，不再等满 15 秒（issue #29）")
    func endNow() {
        var e = SessionEpisode()
        _ = e.connected(at: at(0))
        _ = e.disconnected(at: at(1))
        #expect(e.endNow() == .ended)
        #expect(!e.isActive)
        #expect(e.advance(to: at(2)) == nil)
    }

    @Test("不在重连窗口里时「立即结束」什么都不做")
    func endNowOutsideWindow() {
        var e = SessionEpisode()
        #expect(e.endNow() == nil)
        _ = e.connected(at: at(0))
        #expect(e.endNow() == nil)
        #expect(e.isActive)
    }

    @Test("窗口过了才来的连入：先结束旧会话，再开始新会话")
    func lateReconnect() {
        var e = SessionEpisode()
        _ = e.connected(at: at(0))
        _ = e.disconnected(at: at(1))
        #expect(e.advance(to: at(17)) == .ended)
        #expect(e.connected(at: at(17)) == .began)
    }
}

@Suite("远程会话 RemoteSession")
struct RemoteSessionTests {
    private let present = UUSignals(overlayVisible: false, controllers: .shown(["iPhone"]), captureActive: nil)
    private let absent = UUSignals(overlayVisible: false, controllers: .unrecognized, captureActive: nil)

    @Test("连入 → began；断开 → interrupted；窗口内重连 → resumed；窗口过后 → ended")
    func transitions() {
        var s = RemoteSession()
        #expect(s.update(present, now: at(0)) == [.began(controllers: ["iPhone"])])
        #expect(s.update(absent, now: at(1.0)) == [])
        #expect(s.update(absent, now: at(2.0)) == [.interrupted])
        #expect(s.isConnected == false)
        #expect(s.inEpisode)
        #expect(s.update(present, now: at(3.0)) == [.resumed(controllers: ["iPhone"])])
        #expect(s.update(absent, now: at(5.0)) == [.interrupted])
        #expect(s.update(absent, now: at(20.0)) == [])
        #expect(s.update(absent, now: at(20.1)) == [.ended])
        #expect(!s.inEpisode)
    }

    @Test("窗口过后同一拍又连上：先 ended 再 began")
    func endedThenBegan() {
        var s = RemoteSession()
        _ = s.update(present, now: at(0))
        _ = s.update(absent, now: at(2.0))
        #expect(s.update(present, now: at(30)) == [.ended, .began(controllers: ["iPhone"])])
    }

    @Test("重连窗口里立即结束：透传 ended，会话随之结束（issue #29）")
    func endNow() {
        var s = RemoteSession()
        _ = s.update(present, now: at(0))
        _ = s.update(absent, now: at(2.0))
        #expect(s.endNow() == .ended)
        #expect(!s.inEpisode)
        #expect(s.update(absent, now: at(3.0)) == [])
    }

    @Test("控制端变化透传为 controllersChanged")
    func controllersChanged() {
        var s = RemoteSession()
        _ = s.update(UUSignals(overlayVisible: true, controllers: .unreadable, captureActive: nil), now: at(0))
        #expect(s.update(present, now: at(0.5)) == [.controllersChanged(["iPhone"])])
        #expect(s.controllers == ["iPhone"])
    }

    @Test("回归 #1：没认出控制端、推流一直在，远程不断开；停流后照常 interrupted、ended")
    func unrecognizedTableKeepsStreamingSession() {
        var s = RemoteSession()
        let streaming = UUSignals(overlayVisible: false, controllers: .unrecognized, captureActive: true)
        let stopped = UUSignals(overlayVisible: false, controllers: .unrecognized, captureActive: false)
        #expect(s.update(streaming, now: at(0)) == [.began(controllers: [])])
        for seconds in [0.5, 59.5, 60, 60.5, 75.6, 300] {
            #expect(s.update(streaming, now: at(seconds)) == [])
        }
        #expect(s.inEpisode)
        #expect(s.update(stopped, now: at(300.5)) == [])
        #expect(s.update(stopped, now: at(301.6)) == [.interrupted])
        #expect(s.update(stopped, now: at(316.7)) == [.ended])
    }

    @Test("自扰静默期经 RemoteSession 转给 tracker")
    func selfInduced() {
        var s = RemoteSession()
        _ = s.update(present, now: at(0))
        s.noteSelfInducedChange(at: at(0))
        #expect(s.update(absent, now: at(4.0)) == [])
        #expect(s.update(absent, now: at(5.1)) == [.interrupted])
    }
}

@Suite("换手接管 RemoteSession")
struct HandoverTests {
    private let streaming = UUSignals(overlayVisible: false, controllers: .unrecognized, captureActive: true)
    private let stopped = UUSignals(overlayVisible: false, controllers: .unrecognized, captureActive: false)

    @Test("换手慢到断开了（推流停过了宽限）：还在 15 秒重连等待期里，算同一次远程（ScreenPlan 只看在不在远程，屏不撤）")
    func slowTakeover() {
        var s = RemoteSession()
        _ = s.update(streaming, now: at(0))
        _ = s.update(streaming, now: at(9.5))
        #expect(s.update(stopped, now: at(10)) == [])
        #expect(s.update(stopped, now: at(11.1)) == [.interrupted])
        #expect(s.inEpisode)
        #expect(s.update(streaming, now: at(20)) == [.resumed(controllers: [])])
        #expect(s.inEpisode)
    }
}
