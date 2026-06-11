# HANDOVER

Updated: 2026-06-11 JST

rubyfree = マウスホバーで画面上の漢字にふりがな（ルビ）を透明オーバーレイ表示する macOS 常駐ユーティリティ（完全ローカル・非通信・個人開発OSS / MIT）。

## 1. このセッションで完了したこと（Done）
v0.9.0 公開後、**設定拡充エピック #14（#15〜#19）を完了**し **v0.9.1 を公開**。
- **設定基盤 #15（`7411c3e`）**: `SettingsStore` に fontSize(16…32)/maxReadings(1…4)/settleDelay(0.15…1.0)/schemaVersion 追加（`SettingsBounds` に範囲・クランプ集約）。`RubyTheme.makeStyle(fontSize:maxReadings:)`、`AppCoordinator` 注入＋setter、メニュー段階選択。
- **設定ウィンドウ #16（merge `60d2fac`）**: `SettingsWindowController`（NSWindow+SwiftUI Form）。文字サイズ/候補数/反応速度をスライダ編集→即反映。`RubyRenderer.vPadTop` 動的化（フォント拡大クリップ対策）。エージェント実装をマージ。
- **カスタムテーマ #17（merge `f95ccc2`）**: `ThemeCodec`（RubyTheme⇄JSON, sRGB正規化, decode失敗→nil）、`SettingsStore.customTheme` 永続、`resolveTheme`（custom→customTheme??default）、5色 ColorPicker＋背景Opacityスライダ、メニュー「カスタム」。エージェント実装＋code-reviewでマージ。
- **ユーザー辞書 #18（`6804051`+`60d2fac`）**: `UserDictionaryStore`（`~/Library/Application Support/rubyfree/user-dict.tsv`、サニタイズ surface≤16・読みカナ正規化≤32・1000件・改竄ファイル読込再検証）、`ReadingDictionary.merging`（ユーザー上書き）、編集UI（設定ウィンドウ Table）、編集後 `rebuildAnalyzer` で即反映。**security-reviewer APPROVE**。
- **誤読修正導線 #19（`47a22a1`）**: `AppCoordinator` が直前グロス語をメモリ保持（非永続・非ログ・OFFで破棄）、メニュー「『<語>』の読みを修正…」→NSAlert プリフィル→`addUserReading`。
- **UX微調整（`e3805eb`）**: 設定ウィンドウにテーマプリセット選択（カスタムの上）、カスタム保存に「保存しました ✓」確認表示。
- **v0.9.1 公開（`f1adad7`）**: Info.plist 0.9.0→0.9.1、`release.sh` で ad-hoc 配布、GitHub Release 公開（prerelease）。

## 2. いまの状態（State）
- ブランチ `main`、HEAD **`f1adad7`**、作業ツリー clean、未push無し。CI **green**。
- テスト: **Core 216 + System 57 passed**、Core カバレッジ **98%超**、非通信ガード・バイナリ監査 **PASS**。
- **公開リリース**: `v0.9.1`（prerelease）= https://github.com/yyyyyyy0/rubyfree/releases/tag/v0.9.1 。SHA-256 `74b38b2453f422a18da57dde416217bb4500ccc3db593fa70da03bea69a8a6f7`。v0.9.0 も公開済み。
- `~/Applications/rubyfree.app` は dev-cert ビルドで稼働中（実機確認OK）。

## 3. 決定事項（Decisions）
- **設定UI = メニュー併存＋独立ウィンドウ**（カラーピッカー/辞書テーブルはメニュー不可。SwiftUIは app層に閉じ Core純粋性維持）。
- **カスタムテーマ色は app/System 境界で NSColor⇄sRGB hex 変換**（RubyTheme は CGColor のまま不変）。Opacity は chip背景 alpha のみに合成（**本文/ルビは常に不透明**＝「全体が薄く見える」は白背景でのコントラスト低下で仕様どおり・非対応合意）。
- **ユーザー辞書＝設定値**（非永続ルールの例外。明示登録のみ永続、取得テキストの自動辞書化は禁止。README/PRIVACY に明文化）。capture側送り仮名ゲートへの反映は次回起動（analyzer は即時 rebuild）。
- **並列実装の分担**: エージェント空振り（#18初回）が起きたため、機微(#18)/レビュー必須は直接、独立UI(#16/#17)はエージェント＋code/security-review＋手動マージ衝突解消、という運用に。

## 4. 次にやること（Next）
1. **v0.9 ゲート（#10）**: AXのみMVPを約1週間自己使用して再評価（運用評価）。完了条件: 所見を出して #10 close。
2. (将来) **M5（#11）**: OCRハードニング（2倍アップスケール＋`usesLanguageCorrection` A/B）＋遅延<300-500ms 実測。完了条件: 結果を #11 に記録。
3. (任意) **#6 S0-6**: AX非対応アプリの可否マトリクス。
4. (任意) 設定の後送り候補（A3フォント選択 / A5淡色濃度 / B3ログイン起動 / B4ホットキー / D除外アプリ）。

## 5. 罠・注意点（Pitfalls）
- **git add の複数パスは1つでも不存在だと全体失敗** → 取りこぼし事故。**push 後は `git show --stat`＋CI緑を必ず確認**（ローカル緑でも push 内容が壊れることがある。実例 `9fe0478`→`2a420bf` で修復）。
- **`set -o pipefail` + `grep -q` は SIGPIPE 誤判定** → 出力を変数に取ってから grep（`release.sh` 対処済）。
- **`release.sh` は `dist/` を `rm -rf`** する（notes はそこに置くと消える。今回 `dist/notes-091.md` で再生成）。
- **TinyTest `expectEqual` はメッセージ引数を取らない**（第3引数の文字列は `file:` 扱いでコンパイルエラー）。`expectTrue` はメッセージ可。
- **NSMenu はデフォルト autoenablesItems=true** → action付き項目の手動 isEnabled は効かない。`validateMenuItem` で制御（修正導線で対処）。
- **辞書はバンドルリソース**。`build-app.sh` が `*.bundle` をコピー必須（漏れると静かに degrade、`RUBYFREE_DEBUG` の `analyzer=...` で判別）。
- **実機確認は固定パス `~/Applications/rubyfree.app`（`run-dev.sh`）経由**。run-dev は旧インスタンスを pkill。**画面収録は付与後に再起動が必要**。**Vision `.fast` 禁止**（`.accurate`固定）。
- **CFBundleIdentifier 変更厳禁**（`io.github.yyyyyyy0.rubyfree`、TCC紐付け）。
- **配布署名はアドホック固定**（`release.sh` が `RUBYFREE_SIGN_IDENTITY=-`）。未公証＝右クリック開く＋SHA照合。
- **アイコン再生成**: `swift Scripts/make-icon.swift Scripts/AppIcon.iconset && iconutil -c icns Scripts/AppIcon.iconset -o Scripts/AppIcon.icns`。
- **ファイル削除は trash**（rm はブロック）。

## 6. 重要リンク・参照（References）
- リポジトリ: https://github.com/yyyyyyy0/rubyfree （最新 main `f1adad7`）
- リリース: v0.9.1 https://github.com/yyyyyyy0/rubyfree/releases/tag/v0.9.1
- プラン(SSOT): `/Users/nil/.claude/plans/polished-hatching-mango.md`
- プロジェクトメモリ: `/Users/nil/.claude/projects/-Users-nil-src-rubyfree/memory/rubyfree-spec.md`
- 主要ファイル（設定拡充）:
  - 設定: `Sources/RubyfreeSystem/Settings/`(SettingsStore[SettingsBounds/customTheme] / ThemeCodec), `Sources/rubyfree/Settings/`(SettingsWindowController[SettingsFormView] / ThemePickerView / CustomThemeEditorView / UserDictionaryEditorView)
  - 辞書: `Sources/RubyfreeSystem/Dictionary/UserDictionaryStore.swift`, `Sources/RubyfreeCore/Analyze/ReadingDictionary.swift`(merging)
  - 結線: `Sources/rubyfree/AppCoordinator.swift`(theme/style/設定/辞書ファサード/lastGlossedSurface), `Sources/rubyfree/MenuController.swift`(テーマ/段階選択/修正導線/About), `Sources/rubyfree/main.swift`(merged辞書/rebuildAnalyzer)
  - 配布: `Scripts/release.sh` / `build-app.sh` / `make-icon.swift` / `AppIcon.icns` / `Info.plist.template`(0.9.1)
- コマンド:
  - 実機起動: `./Scripts/run-dev.sh` ／ 検証: `./Scripts/pre-push.sh` ／ リリース生成: `./Scripts/release.sh`
  - 個別テスト: `swift run RubyfreeCoreTests` / `RubyfreeSystemTests`
  - デバッグ観測: `RUBYFREE_DEBUG=1 ~/Applications/rubyfree.app/Contents/MacOS/rubyfree`（len/offset/座標のみ・生テキスト非出力）
- Issues: **closed** #1-5,#7-9,#12-19 ／ **open** #11(M5 OCR), #10(M4 v0.9運用ゲート), #6(S0-6)。

## Changelog
- 2026-06-11: v0.9.1 公開（設定拡充: 表示設定/テーマプリセット/カスタムテーマ/ユーザー辞書/誤読修正）`f1adad7`。エピック #14 と #15-19 close。
- 2026-06-11: v0.9.0 公開（prerelease, ad-hoc）。M6検証5点+クリーンインストール記録し #12 close `613b442`。
- 2026-06-11: アプリアイコン `316e8d4` / About `ca84def` / 送り仮名修正 `2a420bf` / テーマ8種 `ecaec09`。
- 2026-06-11: M4実装（メニューON/OFF・権限喪失検出・設定永続）`8e64da7`、#9 close（前セッション）。
