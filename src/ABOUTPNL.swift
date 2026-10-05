/*
	ABOUTPNL.swift

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
	ABOUT PaNeL

	Replaces the About text that the control overlay used to draw
	into the emulated screen.

	Version and name are read from the bundle rather than written
	here, because the generator already puts them into Info.plist
	from the arguments given to setuptool.
*/

import SwiftUI
import AppKit

struct AboutView: View {

	private var version: String {
		Bundle.main.object(
			forInfoDictionaryKey: "CFBundleShortVersionString")
			as? String ?? ""
	}

	var body: some View {
		VStack(spacing: 12) {
			if let icon = NSApp.applicationIconImage {
				Image(nsImage: icon)
					.resizable()
					.frame(width: 96, height: 96)
			}

			Text(Bundle.main.appName)
				.font(.title2)
				.bold()

			if !version.isEmpty {
				Text("Version \(version)")
					.font(.callout)
					.foregroundStyle(.secondary)
			}

			Text("A miniature Macintosh 68K emulator.")
				.font(.callout)
				.multilineTextAlignment(.center)

			Text("Originally written by Paul C. Pratt.")
				.font(.footnote)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.padding(24)
		.frame(width: 320)
	}
}

/// Owns the single About window.
@objc(MNVMAboutPanel)
final class AboutPanel: NSObject {

	private static var window: NSWindow?

	@objc static func show() {
		if let existing = window {
			existing.makeKeyAndOrderFront(nil)
			return
		}

		let w = NSWindow(
			contentRect: .zero,
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false)
		w.title = "About \(Bundle.main.appName)"
		w.contentView = NSHostingView(rootView: AboutView())
		w.isReleasedWhenClosed = false
		w.center()

		window = w
		w.makeKeyAndOrderFront(nil)
	}
}
