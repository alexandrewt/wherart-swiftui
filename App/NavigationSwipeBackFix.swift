import SwiftUI
import UIKit

// MARK: - Swipe Back Enabler
//
// SwiftUI disables the interactive pop (swipe-from-edge) gesture whenever a
// screen hides its navigation bar or back button (e.g. via .navigationBarHidden).
// Attaching this modifier re-assigns the gesture's delegate directly on the
// underlying UINavigationController, which restores the native swipe-back
// behaviour regardless of bar/back-button visibility.
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let navigationController = uiViewController.navigationController else { return }
            context.coordinator.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

extension View {
    /// Ensures the native swipe-from-left-edge back gesture works on this screen,
    /// even when the navigation bar or back button is hidden.
    func enableSwipeBack() -> some View {
        background(SwipeBackEnabler())
    }
}
