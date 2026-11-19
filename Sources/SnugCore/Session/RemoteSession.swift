// 会话层的组合：连接判定 + 会话生命周期，把每拍观测变成功能模块要处理的会话变化。
// 功能模块（屏幕调度）只消费会话状态，会话层不知道有哪些功能。
// UU 同一时刻只让一台设备控制一台 Mac（实测 V12）：第二台只能「接管设备」，前一台的推流停掉 0.6～0.7 秒后新的一台起推流，
// 落在重连等待期里，算同一次远程。控制端表格的读取保留，只当作「有人在远程」的证据之一，不拿来判断设备类型
import Foundation

public enum SessionTransition: Equatable, Sendable {
    /// 新会话开始
    case began(controllers: [String])
    /// 重连窗口内再连上，仍是同一会话
    case resumed(controllers: [String])
    case controllersChanged([String])
    /// 断开，进入重连窗口
    case interrupted
    /// 重连窗口过了，会话结束
    case ended
}

public struct RemoteSession: Sendable {
    public private(set) var tracker = ConnectionTracker()
    public private(set) var episode = SessionEpisode()

    public init() {}

    public var isConnected: Bool { tracker.isConnected }
    /// 此刻连着的控制端（断开时为空）
    public var controllers: [String] { tracker.controllers }
    public var inEpisode: Bool { episode.isActive }

    public mutating func update(_ signals: UUSignals, now: Date) -> [SessionTransition] {
        var out: [SessionTransition] = []
        if episode.advance(to: now) == .ended { out.append(.ended) }
        switch tracker.update(signals, now: now) {
        case .connected(let names)?:
            if episode.connected(at: now) == .began {
                out.append(.began(controllers: names))
            } else {
                out.append(.resumed(controllers: names))
            }
        case .controllersChanged(let names)?:
            out.append(.controllersChanged(names))
        case .disconnected?:
            if episode.disconnected(at: now) == .interrupted { out.append(.interrupted) }
        case nil:
            break
        }
        return out
    }

    /// 用户不等重连窗口，立即结束本次会话；不在重连窗口里时什么都不做
    public mutating func endNow() -> SessionTransition? {
        episode.endNow().map { _ in .ended }
    }

    public mutating func noteSelfInducedChange(at date: Date) {
        tracker.noteSelfInducedChange(at: date)
    }
}
