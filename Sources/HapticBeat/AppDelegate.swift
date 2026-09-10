import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var viewModel: HapticBeatViewModel?

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

        // Configure Popover
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: 420)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: vm))
        self.popover = pop

        print("HapticBeat menu bar application running.")
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let pop = popover else { return }
        if pop.isShown {
            pop.performClose(sender)
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
}
