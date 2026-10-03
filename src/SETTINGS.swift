/*
	SETTINGS.swift

	Copyright (C) 2026 Moof contributors

	You can redistribute this file and/or modify it under the terms
	of version 2 of the GNU General Public License as published by
	the Free Software Foundation.  You should have received a copy
	of the license along with this file; see the file COPYING.

	This file is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	license for more details.
*/

/*
	SETTINGS window

	Replaces the character cell overlay that used to be drawn into
	the emulated screen and driven by single letter keys.

	SwiftUI's Settings scene is not used, because that requires the
	SwiftUI App lifecycle and AppKit owns this application. The
	window is an ordinary NSWindow hosting the view, which is the
	usual arrangement for an AppKit application adopting SwiftUI.

	Only state the emulator can change while running appears here.
	The machine model, memory size, screen size and colour depth are
	decided when the build is generated and there is no mechanism
	that could honour changing them, so offering them would be a lie.
*/

import SwiftUI
import AppKit
import Combine

struct SettingsView: View {

	@ObservedObject private var bridge = EmulatorBridge.shared

	/*
		The emulator alters this state independently: full screen can
		be left with the green button, the guest can eject a disk.
		Polling while the window is open keeps what is shown honest
		without needing the emulator to know the window exists.
	*/
	private let poll = Timer.publish(every: 0.5, on: .main, in: .common)
		.autoconnect()

	var body: some View {
		Form {
			Section("Speed") {
				Picker("Emulated speed", selection: $bridge.speed) {
					ForEach(EmulatorSpeed.allCases) { option in
						Text(option.title).tag(option)
					}
				}
				Toggle("Pause emulation", isOn: $bridge.isStopped)
				Toggle("Slow down when idle", isOn: $bridge.autoSlow)
				Toggle("Keep running in background",
					isOn: $bridge.runInBackground)
			}

			if bridge.hasMagnify || bridge.hasFullScreen {
				Section("Display") {
					if bridge.hasMagnify {
						Toggle("Magnify", isOn: $bridge.magnify)
					}
					if bridge.hasFullScreen {
						Toggle("Full screen", isOn: $bridge.fullScreen)
					}
				}
			}

			Section("Disks") {
				if bridge.insertedDrives.isEmpty {
					Text("No disks inserted")
						.foregroundStyle(.secondary)
				} else {
					ForEach(bridge.insertedDrives) { drive in
						HStack {
							Text(drive.title)
								.lineLimit(1)
								.truncationMode(.middle)
							Spacer()
							Button("Eject") {
								/*
									The Settings window is key while
									its button is clicked, so the
									question appears as a sheet on it.
								*/
								DiskEjector.eject(drive,
									from: NSApp.keyWindow)
							}
						}
					}
				}
				Button("Open Disk Image…") {
					bridge.insertDisk()
				}
			}
		}
		.formStyle(.grouped)
		.frame(width: 380)
		.fixedSize(horizontal: false, vertical: true)
		.onReceive(poll) { _ in
			bridge.refresh()
		}
		.onAppear {
			bridge.refresh()
		}
	}
}

/// Owns the single Settings window.
@objc(MNVMSettingsWindow)
final class SettingsWindow: NSObject {

	private static var window: NSWindow?

	@objc static func show() {
		if let existing = window {
			existing.makeKeyAndOrderFront(nil)
			return
		}

		let hosting = NSHostingView(rootView: SettingsView())

		let w = NSWindow(
			contentRect: .zero,
			styleMask: [.titled, .closable, .miniaturizable],
			backing: .buffered,
			defer: false)
		w.title = "Settings"
		w.contentView = hosting
		w.isReleasedWhenClosed = false
		w.center()

		window = w
		w.makeKeyAndOrderFront(nil)
	}
}
