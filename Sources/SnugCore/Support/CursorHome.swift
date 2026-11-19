// 指针该落到哪：UU 把指针留在虚拟屏的坐标上，屏一撤，那个坐标不再属于任何屏，指针就“不见了”（issue #29）。
// 这里只算落点，真去挪指针的在 SnugSystem.Cursor
import CoreGraphics

public enum CursorHome {
    /// 指针不在任何一块留下的屏上时，给它一个落点：主屏中央；主屏也是要撤的那块就用第一块留下的屏。
    /// 指针在留下的屏上时返回 nil：用户已经找回来了，不动
    public static func landing(pointer: CGPoint, kept: [CGRect], main: CGRect) -> CGPoint? {
        if kept.contains(where: { $0.contains(pointer) }) { return nil }
        guard let target = main.isEmpty ? kept.first : main, !target.isEmpty else { return nil }
        return CGPoint(x: target.midX, y: target.midY)
    }
}
