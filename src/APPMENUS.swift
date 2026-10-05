/*
	APPMENUS.swift

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
	APPlication MENUS

	The real menu bar, replacing the three item stub that existed
	when the only way to reach most commands was a character cell
	overlay drawn into the emulated screen.

	Key equivalents use Control, not Command. That is not a style
	choice: the emulated Macintosh receives every Command keystroke,
	so Command is unavailable to the host. What makes this workable
	is that the commands are now discoverable with the mouse, and
	that native full screen reveals the menu bar on hover, so nothing
	is unreachable.

	Check marks and enablement are answered in validateMenuItem
	rather than pushed. The emulator changes this state on its own —
	full screen can be left with the green button, a disk can be
	ejected by the guest — so asking at the moment the menu opens is
	both simpler and more accurate than trying to keep a copy in
	step. The asking happens once, in menuWillOpen; validation then
	reads the copy the bridge just made, because every read of the
	emulator waits on its lock and a menu validates every item.
*/

import AppKit

@objc(MNVMMenuController)
final class MenuController: NSObject, NSMenuItemValidation {

	@objc static let shared = MenuController()

	private var bridge: EmulatorBridge { EmulatorBridge.shared }

	private var appName: String { Bundle.main.appName }

	/// The one menu that is rebuilt, not merely revalidated, on open.
	private var ejectMenu: NSMenu?

	private override init() {
		super.init()
	}

	/// Builds and installs the application menu bar.
	@objc static func installMainMenu() {
		let controller = MenuController.shared
		let mainMenu = NSMenu()

		mainMenu.addItem(controller.makeAppMenuItem())
		mainMenu.addItem(controller.makeFileMenuItem())
		mainMenu.addItem(controller.makeMachineMenuItem())
		mainMenu.addItem(controller.makeViewMenuItem())
		mainMenu.addItem(controller.makeWindowMenuItem())

		NSApp.mainMenu = mainMenu
	}

	// MARK: building

	/*
		Every menu made here has this controller as its delegate, so
		that menuWillOpen can refresh the bridge once before the items
		are validated.
	*/
	private func submenu(_ title: String, _ build: (NSMenu) -> Void)
		-> NSMenuItem
	{
		let menu = NSMenu(title: title)
		menu.delegate = self
		build(menu)

		let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
		item.submenu = menu

		return item
	}

	@discardableResult
	private func add(_ menu: NSMenu, _ title: String,
		_ action: Selector, key: String = "",
		mask: NSEvent.ModifierFlags = .control,
		tag: Int = 0) -> NSMenuItem
	{
		let item = NSMenuItem(title: title, action: action,
			keyEquivalent: key)
		item.keyEquivalentModifierMask = mask
		item.target = self
		item.tag = tag
		menu.addItem(item)

		return item
	}

	private func makeAppMenuItem() -> NSMenuItem {
		/*
			macOS substitutes the real application name for the first
			menu's title, so what is passed here does not show.
		*/
		return submenu(appName) { menu in
			add(menu, "About \(appName)",
				#selector(showAbout(_:)))
			menu.addItem(.separator())
			add(menu, "Settings…",
				#selector(showSettings(_:)), key: ",")
			menu.addItem(.separator())

			let hide = NSMenuItem(title: "Hide \(appName)",
				action: #selector(NSApplication.hide(_:)),
				keyEquivalent: "")
			menu.addItem(hide)

			let hideOthers = NSMenuItem(title: "Hide Others",
				action: #selector(NSApplication.hideOtherApplications(_:)),
				keyEquivalent: "")
			menu.addItem(hideOthers)

			let showAll = NSMenuItem(title: "Show All",
				action: #selector(NSApplication.unhideAllApplications(_:)),
				keyEquivalent: "")
			menu.addItem(showAll)

			menu.addItem(.separator())

			let quit = NSMenuItem(title: "Quit \(appName)",
				action: #selector(NSApplication.terminate(_:)),
				keyEquivalent: "q")
			quit.keyEquivalentModifierMask = .control
			menu.addItem(quit)
		}
	}

	private func makeFileMenuItem() -> NSMenuItem {
		return submenu("File") { menu in
			add(menu, "Open Disk Image…",
				#selector(openDiskImage(_:)), key: "o")
			menu.addItem(.separator())

			/*
				Populated in menuNeedsUpdate, because which drives
				hold a disk changes as the guest runs.
			*/
			let eject = submenu("Eject") { _ in }
			ejectMenu = eject.submenu
			menu.addItem(eject)
		}
	}

	private func makeMachineMenuItem() -> NSMenuItem {
		return submenu("Machine") { menu in
			add(menu, "Reset", #selector(resetMachine(_:)), key: "r")
			add(menu, "Interrupt", #selector(interruptMachine(_:)),
				key: "i")
			menu.addItem(.separator())

			menu.addItem(submenu("Speed") { speedMenu in
				for option in EmulatorSpeed.allCases {
					add(speedMenu, option.title, #selector(setSpeed(_:)),
						mask: [], tag: option.rawValue)
				}
			})

			add(menu, "Pause", #selector(toggleStopped(_:)))
			menu.addItem(.separator())
			add(menu, "Run in Background",
				#selector(toggleRunInBackground(_:)))
			add(menu, "Slow Down When Idle",
				#selector(toggleAutoSlow(_:)))
		}
	}

	private func makeViewMenuItem() -> NSMenuItem {
		return submenu("View") { menu in
			if bridge.hasMagnify {
				add(menu, "Magnify", #selector(toggleMagnify(_:)),
					key: "m")
			}
			/*
				Full screen is left to AppKit's own item, which
				drives toggleFullScreen: and so keeps the green
				button, Spaces and the auto revealing menu bar
				behaving as they should.
			*/
			let full = NSMenuItem(title: "Enter Full Screen",
				action: #selector(NSWindow.toggleFullScreen(_:)),
				keyEquivalent: "f")
			full.keyEquivalentModifierMask = [.control, .command]
			menu.addItem(full)
		}
	}

	private func makeWindowMenuItem() -> NSMenuItem {
		let item = submenu("Window") { menu in
			let minimise = NSMenuItem(title: "Minimise",
				action: #selector(NSWindow.performMiniaturize(_:)),
				keyEquivalent: "")
			menu.addItem(minimise)

			let zoom = NSMenuItem(title: "Zoom",
				action: #selector(NSWindow.performZoom(_:)),
				keyEquivalent: "")
			menu.addItem(zoom)
		}
		NSApp.windowsMenu = item.submenu

		return item
	}

	// MARK: actions

	@objc private func showAbout(_ sender: Any?) {
		AboutPanel.show()
	}

	@objc private func showSettings(_ sender: Any?) {
		SettingsWindow.show()
	}

	@objc private func openDiskImage(_ sender: Any?) {
		bridge.insertDisk()
	}

	@objc private func resetMachine(_ sender: Any?) {
		bridge.reset()
	}

	@objc private func interruptMachine(_ sender: Any?) {
		bridge.interrupt()
	}

	@objc private func setSpeed(_ sender: Any?) {
		guard let item = sender as? NSMenuItem,
			let option = EmulatorSpeed(rawValue: item.tag) else { return }

		bridge.refresh(force: true)
		bridge.speed = option
	}

	/*
		The toggles reread first, so that they flip the value the
		emulator has now and not the one shown when the menu opened,
		which could be a second or more old by the time the item is
		chosen.
	*/
	@objc private func toggleStopped(_ sender: Any?) {
		bridge.refresh(force: true)
		bridge.isStopped.toggle()
	}

	@objc private func toggleMagnify(_ sender: Any?) {
		bridge.refresh(force: true)
		bridge.magnify.toggle()
	}

	@objc private func toggleRunInBackground(_ sender: Any?) {
		bridge.refresh(force: true)
		bridge.runInBackground.toggle()
	}

	@objc private func toggleAutoSlow(_ sender: Any?) {
		bridge.refresh(force: true)
		bridge.autoSlow.toggle()
	}

	@objc private func ejectDrive(_ sender: Any?) {
		guard let item = sender as? NSMenuItem,
			let drive = item.representedObject as? DiskDriveBox
		else { return }

		DiskEjector.eject(drive.drive, from: nil)
	}

	// MARK: validation

	/*
		Reads the bridge's published copy, refreshed in menuWillOpen
		just before this is called for each item. Nothing here touches
		the C surface or the emulator lock.
	*/
	func validateMenuItem(_ item: NSMenuItem) -> Bool {
		switch item.action {
		case #selector(setSpeed(_:)):
			item.state = (bridge.speed.rawValue == item.tag) ? .on : .off
			return true

		case #selector(toggleStopped(_:)):
			item.state = bridge.isStopped ? .on : .off
			return true

		case #selector(toggleMagnify(_:)):
			item.state = bridge.magnify ? .on : .off
			return bridge.hasMagnify

		case #selector(toggleRunInBackground(_:)):
			item.state = bridge.runInBackground ? .on : .off
			return true

		case #selector(toggleAutoSlow(_:)):
			item.state = bridge.autoSlow ? .on : .off
			return true

		case #selector(ejectDrive(_:)):
			return true

		default:
			return true
		}
	}
}

extension MenuController: NSMenuDelegate {

	/*
		One pass over the emulator per menu opened, forced so that it
		is not skipped as too soon after the Settings poll, and so
		that image names are reread: a drive may have had its disk
		swapped since anyone last looked. The Eject submenu has
		already refreshed in menuNeedsUpdate, which AppKit calls
		first.
	*/
	func menuWillOpen(_ menu: NSMenu) {
		guard menu !== ejectMenu else { return }

		bridge.refresh(force: true)
	}

	/*
		The Eject submenu is rebuilt each time it opens, since the set
		of occupied drives changes while the guest runs. AppKit calls
		this for every menu with a delegate, so the others are left
		alone.
	*/
	func menuNeedsUpdate(_ menu: NSMenu) {
		guard menu === ejectMenu else { return }

		menu.removeAllItems()

		bridge.refresh(force: true)

		if bridge.insertedDrives.isEmpty {
			let empty = NSMenuItem(title: "No Disks Inserted",
				action: nil, keyEquivalent: "")
			empty.isEnabled = false
			menu.addItem(empty)
			return
		}

		for drive in bridge.insertedDrives {
			let item = NSMenuItem(title: drive.title,
				action: #selector(ejectDrive(_:)), keyEquivalent: "")
			item.target = self
			item.tag = drive.index
			item.representedObject = DiskDriveBox(drive)
			menu.addItem(item)
		}
	}
}

/*
	Carries a DiskDrive in an NSMenuItem's representedObject, so the
	action knows which image the user picked and not only which slot.
*/
private final class DiskDriveBox: NSObject {
	let drive: DiskDrive

	init(_ drive: DiskDrive) {
		self.drive = drive
	}
}

/*
	Ejecting from the host, shared by the File menu and the Settings
	window.

	The host can always take an image out, safely as far as the
	emulator is concerned, but the guest is not told: to the emulated
	Mac it is a disk yanked from the drive, with whatever it had not
	yet written lost, and System 6 or 7 then asks for it back. So
	once the guest has mounted a disk, the user is asked first and
	pointed at the proper way. A disk the guest has not mounted yet
	is simply removed.
*/
enum DiskEjector {

	/// Ejects `drive`, asking first if the guest has it mounted. With
	/// a window the question is a sheet on it, otherwise app modal.
	static func eject(_ drive: DiskDrive, from window: NSWindow?) {
		let bridge = EmulatorBridge.shared

		guard bridge.isMountedByGuest(drive: drive.index) else {
			bridge.eject(drive: drive.index)
			return
		}

		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = "The emulated Mac is still using "
			+ (drive.imageName.map { "“\($0)”" } ?? "this disk") + "."
		alert.informativeText = "Eject it in the emulated Mac first, "
			+ "by dragging its icon to the Trash or choosing Eject "
			+ "from the Finder’s Special menu. Ejecting it here is "
			+ "like pulling a disk out of a running Mac: changes not "
			+ "yet written to it can be lost."

		let ejectButton = alert.addButton(withTitle: "Eject Anyway")
		ejectButton.hasDestructiveAction = true
		let cancelButton = alert.addButton(withTitle: "Cancel")

		/*
			Return cancels rather than ejects, so that dismissing the
			alert without reading it is the safe choice.
		*/
		ejectButton.keyEquivalent = ""
		cancelButton.keyEquivalent = "\r"

		let finish = { (response: NSApplication.ModalResponse) in
			guard response == .alertFirstButtonReturn else { return }

			/*
				The emulator kept running while the question was up.
				If the guest has ejected the disk meanwhile, or
				another image now sits in the drive, the answer no
				longer applies to it.
			*/
			guard bridge.currentDrive(drive.index) == drive else {
				bridge.refresh(force: true)
				return
			}
			bridge.eject(drive: drive.index)
		}

		if let window {
			alert.beginSheetModal(for: window, completionHandler: finish)
		} else {
			finish(alert.runModal())
		}
	}
}

extension Bundle {
	/*
		Taken from the bundle rather than written into the sources,
		so that the application name lives in exactly one place: the
		generator puts kStrAppName into Info.plist, and everything
		else reads it back.
	*/
	var appName: String {
		object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Moof"
	}
}
