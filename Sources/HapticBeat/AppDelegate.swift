import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var viewModel: HapticBeatViewModel?
    private var hostingController: NSHostingController<MenuBarView>?

    @MainActor
    public func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = HapticBeatViewModel()
        self.viewModel = vm

        // Configure Status Bar Item
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "HapticBeat")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        self.statusItem = item

        // Configure Popover with dynamic fitting size
        let controller = NSHostingController(rootView: MenuBarView(viewModel: vm))
        self.hostingController = controller

        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentViewController = controller
        let fitting = controller.view.fittingSize
        pop.contentSize = NSSize(width: max(350, fitting.width), height: max(480, fitting.height))
        self.popover = pop

        print("HapticBeat menu bar application running.")
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let pop = popover, let controller = hostingController else { return }
        if pop.isShown {
            pop.performClose(sender)
        } else {
            let fitting = controller.view.fittingSize
            pop.contentSize = NSSize(width: max(350, fitting.width), height: max(480, fitting.height))
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
}
