import AVFoundation
import SwiftUI
import UIKit

/// Thin `UIViewRepresentable` that hosts an `AVCaptureVideoPreviewLayer`.
///
/// Doesn't try to be clever — it just sizes the layer to the view bounds and
/// sets the session. All camera logic lives in `CameraController`.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainer {
        let view = PreviewContainer()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainer, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewContainer: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
