// 远程结束后的指针收拾（issue #29）：UU 把指针留在虚拟屏的坐标上，屏一撤，那个坐标不再属于任何屏，指针就“不见了”；
// 远程期间 UU 还可能把鼠标和指针解绑，物理鼠标动了指针不动。落点怎么算见 SnugCore.CursorHome
import AppKit
import SnugCore

@MainActor
public enum Cursor {
    /// 重新绑定鼠标与指针：远程期间被解绑过的话，物理鼠标就动不了指针
    public static func reattach() {
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// 指针不在任何一块屏上时收回主屏中央（会话结束时兜底，屏已经撤掉的情况下用）
    public static func bringHome() {
        guard let point = CGEvent(source: nil)?.location else { return }
        move(point, keepingOut: nil)
    }

    /// 撤这块屏之前把指针带走：它还停在这块屏上时，落到一块留下的屏中央
    public static func leave(_ gone: DisplayID) {
        let area = CGDisplayBounds(gone)
        guard !area.isEmpty, let point = CGEvent(source: nil)?.location, area.contains(point) else { return }
        move(point, keepingOut: gone)
    }

    private static func move(_ point: CGPoint, keepingOut gone: DisplayID?) {
        let kept = (Screens.online() ?? []).filter { $0 != gone }.map { CGDisplayBounds($0) }
        let mainID = CGMainDisplayID()
        let main = mainID == gone ? .zero : CGDisplayBounds(mainID)
        guard let landing = CursorHome.landing(pointer: point, kept: kept, main: main) else { return }
        CGWarpMouseCursorPosition(landing)
        Log.info("指针不在留下的屏上，收回 \(Int(landing.x)),\(Int(landing.y))（原来 \(Int(point.x)),\(Int(point.y))）")
    }
}
