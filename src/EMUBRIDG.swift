/*
	EMUBRIDG.swift

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
	EMUlator BRIDGe

	The single point at which Swift meets the C emulator. Every other
	Swift file talks to this type and never touches the C surface
	directly, which is what keeps C types out of the view layer.

	Reads go straight through to the emulator, which is cheap: the
	accessors in EMUCTLAP take the emulator lock, and at ordinary
	speeds that lock is free for most of every tick.

	Writes are requests. The emulator polls the flags they set, so a
	change here takes effect on a following tick rather than at once.
	Nothing in the interface should assume a setter is visible
	immediately.
*/

import Foundation
import SwiftUI

/// Emulated speed, as offered in the interface.
enum EmulatorSpeed: Int, CaseIterable, Identifiable {
	case x1 = 0
	case x2 = 1
	case x4 = 2
	case x8 = 3
	case x16 = 4
	case x32 = 5
	case allOut = -1

	var id: Int { rawValue }

	var title: String {
		switch self {
		case .x1: return "1×"
		case .x2: return "2×"
		case .x4: return "4×"
		case .x8: return "8×"
		case .x16: return "16×"
		case .x32: return "32×"
		case .allOut: return "All Out"
		}
	}
}

/// A drive holding a disk image, as offered in the interface.
struct DiskDrive: Identifiable, Equatable {
	/// Zero based drive index.
	let index: Int

	/// File name of the image, if the emulator knows it.
	let imageName: String?

	var id: Int { index }

	/// "Disk 1 — System.dsk", or just "Disk 1".
	var title: String {
		if let imageName {
			return "Disk \(index + 1) — \(imageName)"
		}
		return "Disk \(index + 1)"
	}
}

final class EmulatorBridge: ObservableObject {

	static let shared = EmulatorBridge()

	private init() {
		refresh()
	}

	// MARK: what this build can do

	let hasMagnify = MNVM_HasMagnify()
	let hasFullScreen = MNVM_HasFullScreen()
	let hasSound = MNVM_HasSound()
	let driveCount = Int(MNVM_GetDriveCount())

	// MARK: published state

	@Published var speed: EmulatorSpeed = .x1 {
		didSet {
			guard !isRefreshing, oldValue != speed else { return }
			MNVM_PostSetSpeedValue(Int32(speed.rawValue))
		}
	}

	@Published var isStopped: Bool = false {
		didSet {
			guard !isRefreshing, oldValue != isStopped else { return }
			MNVM_PostSetSpeedStopped(isStopped)
		}
	}

	@Published var magnify: Bool = false {
		didSet {
			guard !isRefreshing, oldValue != magnify else { return }
			MNVM_PostSetMagnify(magnify)
		}
	}

	@Published var fullScreen: Bool = false {
		didSet {
			guard !isRefreshing, oldValue != fullScreen else { return }
			MNVM_PostSetFullScreen(fullScreen)
		}
	}

	@Published var runInBackground: Bool = false {
		didSet {
			guard !isRefreshing, oldValue != runInBackground else { return }
			MNVM_PostSetRunInBackground(runInBackground)
		}
	}

	@Published var autoSlow: Bool = true {
		didSet {
			guard !isRefreshing, oldValue != autoSlow else { return }
			MNVM_PostSetAutoSlow(autoSlow)
		}
	}

	/// The drives that currently hold an image.
	@Published var insertedDrives: [DiskDrive] = []

	/*
		Guards the didSet observers while state is being pulled back
		out of the emulator. Without it, refreshing would post every
		value straight back as a fresh request, and a change the
		emulator made itself would be immediately overwritten by the
		interface echoing the old one.
	*/
	private var isRefreshing = false

	// MARK: reading back

	/// Pulls current emulator state into the published properties.
	func refresh() {
		isRefreshing = true
		defer { isRefreshing = false }

		/*
			Assigned only when different. Every assignment to a
			published property announces a change, and the Settings
			window refreshes twice a second, so writing unchanged
			values would redraw it for nothing.
		*/
		update(\.speed,
			EmulatorSpeed(rawValue: Int(MNVM_GetSpeedValue())) ?? .x1)
		update(\.isStopped, MNVM_GetSpeedStopped())
		update(\.magnify, MNVM_GetMagnify())
		update(\.fullScreen, MNVM_GetFullScreen())
		update(\.runInBackground, MNVM_GetRunInBackground())
		update(\.autoSlow, MNVM_GetAutoSlow())

		update(\.insertedDrives, (0 ..< driveCount).compactMap {
			MNVM_GetDriveInserted(Int32($0))
				? DiskDrive(index: $0, imageName: imageName(drive: $0))
				: nil
		})
	}

	private func update<T: Equatable>(
		_ property: ReferenceWritableKeyPath<EmulatorBridge, T>,
		_ value: T)
	{
		if self[keyPath: property] != value {
			self[keyPath: property] = value
		}
	}

	private func imageName(drive: Int) -> String? {
		/*
			Generous for a file name, which macOS limits to 255
			UTF-16 units, up to three UTF-8 bytes each.
		*/
		var buffer = [CChar](repeating: 0, count: 1024)

		guard MNVM_CopyDriveName(Int32(drive), &buffer,
			Int32(buffer.count)) else { return nil }

		return String(cString: buffer)
	}

	var anyDriveInserted: Bool { MNVM_GetAnyDriveInserted() }

	// MARK: actions

	func reset() { MNVM_PostReset() }
	func interrupt() { MNVM_PostInterrupt() }
	func insertDisk() { MNVM_PostInsertDisk() }
	func requestQuit() { MNVM_PostQuit() }

	/// Whether the guest has mounted the disk, and so expects to be
	/// the one to eject it.
	func isMountedByGuest(drive: Int) -> Bool {
		MNVM_GetDriveMountedByGuest(Int32(drive))
	}

	/// The image a drive holds now, which may differ from what was
	/// shown to the user a moment ago.
	func currentDrive(_ drive: Int) -> DiskDrive? {
		guard MNVM_GetDriveInserted(Int32(drive)) else { return nil }
		return DiskDrive(index: drive, imageName: imageName(drive: drive))
	}

	func eject(drive: Int) {
		MNVM_PostEjectDrive(Int32(drive))
		refresh()
	}
}
