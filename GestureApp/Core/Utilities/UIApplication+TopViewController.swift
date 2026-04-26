import UIKit

extension UIViewController {
    fileprivate func gesture_topMost() -> UIViewController {
        if let presented = presentedViewController { return presented.gesture_topMost() }
        return self
    }
}

extension UIApplication {
    /// Host for `VKID.authorize(using: .uiViewController(_))`.
    var gesture_topViewController: UIViewController? {
        guard
            let scene = connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return nil }
        return root.gesture_topMost()
    }
}
