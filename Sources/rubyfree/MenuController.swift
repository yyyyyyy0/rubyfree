import AppKit
import RubyfreeCore
import RubyfreeSystem

/// Owns the menu-bar `NSStatusItem` and its menu: an on/off toggle, live permission
/// status, "open System Settings" shortcuts when a grant is missing, and Quit.
///
/// The menu refreshes both on open (`menuNeedsUpdate`) and whenever the coordinator
/// reports a state change (`onStateChange`), so a permission lost while the menu is closed
/// still updates the status-item appearance.
///
/// The "設定…" item is wired via the `openSettings` closure so `MenuController` does not
/// depend on `SettingsWindowController` directly — decoupling is done at the call site
/// (`main.swift`), keeping the menu a pure presentation layer.
@MainActor
final class MenuController: NSObject, NSMenuDelegate {

    private let coordinator: AppCoordinator
    private let permissions: AXPermissionChecker
    private let statusItem: NSStatusItem
    private let useFake: Bool
    /// Invoked when the user chooses "設定…". Supplied by `main.swift` so this class
    /// stays independent of `SettingsWindowController`.
    private let openSettings: @MainActor () -> Void

    private let menu = NSMenu()
    private let toggleItem  = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let axStatus    = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let axOpen      = NSMenuItem(title: "アクセシビリティを設定で開く…", action: nil, keyEquivalent: "")
    private let ocrStatus   = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let screenOpen  = NSMenuItem(title: "画面収録を設定で開く…", action: nil, keyEquivalent: "")
    private let themeItem   = NSMenuItem(title: "テーマ", action: nil, keyEquivalent: "")
    /// One radio item per preset, keyed by theme id, so `refresh()` can tick the active one.
    private var themeItems: [String: NSMenuItem] = [:]
    /// Lazily created menu item for the custom theme (shown only after one has been saved).
    private var customThemeMenuItem: NSMenuItem?

    // Staged display/behaviour selectors (interim until the Settings window, #16). Each is a
    // submenu of radio items; `refresh()` ticks the one matching the coordinator's value.
    private let fontSizeItem    = NSMenuItem(title: "文字サイズ", action: nil, keyEquivalent: "")
    private let maxReadingsItem = NSMenuItem(title: "ルビ候補数", action: nil, keyEquivalent: "")
    private let settleItem      = NSMenuItem(title: "反応の速さ", action: nil, keyEquivalent: "")
    private var fontSizeItems: [Int: NSMenuItem] = [:]
    private var maxReadingsItems: [Int: NSMenuItem] = [:]
    /// Settle-delay options keyed by an integer of milliseconds (avoids Double dictionary keys).
    private var settleItems: [Int: NSMenuItem] = [:]

    private static let fontSizeOptions: [(String, Int)] = [("小", 18), ("中", 22), ("大", 28), ("特大", 32)]
    private static let maxReadingsOptions: [(String, Int)] = [("1", 1), ("2", 2), ("3", 3), ("4", 4)]
    /// (label, seconds). Keyed in the map by `Int(seconds*1000)`.
    private static let settleOptions: [(String, Double)] = [("速い", 0.2), ("標準", 0.35), ("ゆっくり", 0.6)]

    init(coordinator: AppCoordinator,
         permissions: AXPermissionChecker,
         statusItem: NSStatusItem,
         useFake: Bool,
         openSettings: @escaping @MainActor () -> Void) {
        self.coordinator = coordinator
        self.permissions = permissions
        self.statusItem = statusItem
        self.useFake = useFake
        self.openSettings = openSettings
        super.init()
        build()
        coordinator.onStateChange = { [weak self] in self?.refresh() }
        refresh()
    }

    private func build() {
        toggleItem.target = self; toggleItem.action = #selector(toggleEnabled)
        axOpen.target = self;     axOpen.action = #selector(openAXSettings)
        screenOpen.target = self; screenOpen.action = #selector(openScreenSettings)
        axStatus.isEnabled = false
        ocrStatus.isEnabled = false

        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(axStatus)
        menu.addItem(axOpen)
        if !useFake {
            menu.addItem(ocrStatus)
            menu.addItem(screenOpen)
        } else {
            let f = NSMenuItem(title: "（FAKE_CAPTURE モード）", action: nil, keyEquivalent: "")
            f.isEnabled = false
            menu.addItem(f)
        }
        menu.addItem(.separator())
        buildThemeSubmenu()
        menu.addItem(themeItem)
        buildDisplaySubmenus()
        menu.addItem(fontSizeItem)
        menu.addItem(maxReadingsItem)
        menu.addItem(settleItem)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "設定…",
                                  action: #selector(openSettingsWindow), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let about = NSMenuItem(title: "rubyfree について…",
                               action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(withTitle: "rubyfree を終了",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        menu.delegate = self
        statusItem.button?.title = "る"
        statusItem.menu = menu
    }

    /// Build the "テーマ" submenu: one radio item per preset, plus a "カスタム" item appended
    /// dynamically in `refresh()` when a custom theme has been saved. Selecting an item drives
    /// `coordinator.setTheme(id:)`; the active one is ticked in `refresh()`.
    private func buildThemeSubmenu() {
        let submenu = NSMenu()
        for preset in RubyTheme.allPresets {
            let item = NSMenuItem(title: preset.name,
                                  action: #selector(selectTheme(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id
            submenu.addItem(item)
            themeItems[preset.id] = item
        }
        themeItem.submenu = submenu
    }

    /// Ensure the "カスタム" submenu item exists and is visible when a custom theme is present,
    /// or is absent / hidden when none has been saved. Called from `refresh()`.
    private func syncCustomThemeMenuItem() {
        guard let submenu = themeItem.submenu else { return }
        let hasCustom = coordinator.currentCustomTheme != nil

        if hasCustom {
            if customThemeMenuItem == nil {
                let item = NSMenuItem(title: "カスタム",
                                      action: #selector(selectTheme(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = "custom"
                submenu.addItem(.separator())
                submenu.addItem(item)
                customThemeMenuItem = item
                themeItems["custom"] = item
            }
            customThemeMenuItem?.isHidden = false
        } else {
            customThemeMenuItem?.isHidden = true
        }
    }

    /// Build the interim "文字サイズ / ルビ候補数 / 反応の速さ" submenus (staged radio items).
    private func buildDisplaySubmenus() {
        fontSizeItem.submenu = radioSubmenu(
            Self.fontSizeOptions.map { ($0.0, $0.1) },
            action: #selector(selectFontSize(_:)), into: &fontSizeItems)
        maxReadingsItem.submenu = radioSubmenu(
            Self.maxReadingsOptions.map { ($0.0, $0.1) },
            action: #selector(selectMaxReadings(_:)), into: &maxReadingsItems)
        settleItem.submenu = radioSubmenu(
            Self.settleOptions.map { ($0.0, Int($0.1 * 1000)) },
            action: #selector(selectSettle(_:)), into: &settleItems)
    }

    /// Make a submenu of radio items from (label, Int value) pairs. The value is stored as
    /// `representedObject` and the item is registered in `map` keyed by value for `refresh()`.
    private func radioSubmenu(_ options: [(String, Int)],
                              action: Selector,
                              into map: inout [Int: NSMenuItem]) -> NSMenu {
        let submenu = NSMenu()
        for (label, value) in options {
            let item = NSMenuItem(title: label, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = value
            submenu.addItem(item)
            map[value] = item
        }
        return submenu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) { refresh() }

    // MARK: - Refresh

    func refresh() {
        let enabled = coordinator.isEnabled
        let p = coordinator.currentPermissions()

        toggleItem.title = enabled ? "ふりがな表示: オン" : "ふりがな表示: オフ"
        toggleItem.state = enabled ? .on : .off

        axStatus.title = p.accessibility ? "アクセシビリティ: 許可済み ✓"
                                         : "アクセシビリティ: 未許可 ✗（ふりがな不可）"
        axOpen.isHidden = p.accessibility

        if !useFake {
            ocrStatus.title = p.screenRecording
                ? "OCRフォールバック: 有効 ✓"
                : "OCRフォールバック: 画面収録の許可が必要（許可後に再起動）"
            screenOpen.isHidden = p.screenRecording
        }

        // Add or hide the カスタム radio item depending on whether a custom theme is saved.
        syncCustomThemeMenuItem()

        // Tick the active theme's radio item.
        let activeThemeID = coordinator.currentThemeID
        for (id, item) in themeItems {
            item.state = (id == activeThemeID) ? .on : .off
        }
        // Tick the active display/behaviour selectors.
        tick(fontSizeItems, active: coordinator.currentFontSize)
        tick(maxReadingsItems, active: coordinator.currentMaxReadings)
        tick(settleItems, active: Int(coordinator.currentSettleDelay * 1000))

        // Dim the menu-bar glyph when turned off, as a passive on/off cue.
        statusItem.button?.appearsDisabled = !enabled
    }

    /// Tick exactly the radio item whose value equals `active`.
    private func tick(_ items: [Int: NSMenuItem], active: Int) {
        for (value, item) in items { item.state = (value == active) ? .on : .off }
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        coordinator.setEnabled(!coordinator.isEnabled)
        refresh()
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        coordinator.setTheme(id: id)
        refresh()
    }

    @objc private func selectFontSize(_ sender: NSMenuItem) {
        guard let points = sender.representedObject as? Int else { return }
        coordinator.setFontSize(points)
        refresh()
    }

    @objc private func selectMaxReadings(_ sender: NSMenuItem) {
        guard let count = sender.representedObject as? Int else { return }
        coordinator.setMaxReadings(count)
        refresh()
    }

    @objc private func selectSettle(_ sender: NSMenuItem) {
        guard let ms = sender.representedObject as? Int else { return }
        coordinator.setSettleDelay(Double(ms) / 1000)
        refresh()
    }

    @objc private func openSettingsWindow() { openSettings() }

    @objc private func openAXSettings() { permissions.openAccessibilitySettings() }
    @objc private func openScreenSettings() { permissions.openScreenRecordingSettings() }

    /// Show the native About panel. The credits carry the third-party attribution that
    /// distribution requires — the bundled dictionary is CC BY-SA 4.0, whose attribution
    /// must travel with the binary (a downloader never sees the repo's NOTICE). App name,
    /// version, and copyright are read from Info.plist automatically.
    @objc private func showAbout() {
        // An accessory (LSUIElement) app isn't active, so the panel would open behind other
        // windows; activate first so it comes to the front.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: Self.creditsAttributedString])
    }

    /// Attribution shown in the About panel's scrollable credits area.
    private static var creditsAttributedString: NSAttributedString {
        let body = """
        画面上の漢字にホバーでふりがなを表示する、完全ローカル・非通信のユーティリティ。

        ライセンス
        rubyfree のソースコードは MIT License です。
        © 2026 yyyyyyy0

        同梱辞書データ
        JMdict / KANJIDIC2 — © Electronic Dictionary Research and Development Group (EDRDG)
        Creative Commons Attribution-ShareAlike 4.0 International（CC BY-SA 4.0）の下で利用しています。
        生成された辞書ファイル（words.tsv / kanji.tsv）も CC BY-SA 4.0 で配布されます。
        https://www.edrdg.org/edrdg/licence.html

        ソースコード
        https://github.com/yyyyyyy0/rubyfree
        """
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 6
        return NSAttributedString(string: body, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .paragraphStyle: paragraph,
        ])
    }
}
