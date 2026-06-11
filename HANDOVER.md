# HANDOVER

Updated: 2026-06-11 JST

rubyfree = マウスホバーで画面上の漢字にふりがな（ルビ）を透明オーバーレイ表示する macOS 常駐ユーティリティ（完全ローカル・非通信・個人開発OSS / MIT）。

## 1. このセッションで完了したこと（Done）
本日 main に追加 6 コミット（全 push 済み・CI green）。テーマ機能・送り仮名修正・配布（v0.9.0 公開）まで到達。
- **テーマ/カラーパレット選択（#13, `ecaec09`）**: AppKit非依存 `RubyTheme`（id/name/text色3+chip色2, CGColor）を Core に追加。プリセット8種（dark既定=従来色 / light / 高コントラスト / セピア / オーシャン / フォレスト / サクラ / グレープ）。`SettingsStore.themeID` で永続、`MenuController` にラジオサブメニュー、`RubyRenderer` のchip色を可変化、`OverlayPresenting.applyTheme`。切替時は表示中チップを `hide()` し次ホバーで新テーマに統一。#13 close。
- **漢字＋送り仮名をまとめて読む（`2a420bf`）**: 「宛も」が「あて」になる不具合を修正。捕捉単位の連続漢字ランを後続ひらがなへ拡張し、**辞書に実在する語のときだけ取り込む**（`Okurigana.extend` 辞書ゲート最長一致）。同じ「も」でも宛も(語)は取込・宛＋助詞は非取込。**AX/OCR両経路**に辞書注入（`AXTextCapture` / `VisionTextRecognizer`・`OCRTextCapture`）。`Character.isHiragana` 追加。
- **About パネル（`ca84def`）**: メニュー「rubyfree について…」→ 標準 About パネル。credits に第三者帰属（JMdict/KANJIDIC2 © EDRDG = CC BY-SA 4.0）と rubyfree=MIT。CC BY-SA 帰属を**バイナリ配布物に同伴**（DL者は repo NOTICE を見ない）。
- **アプリアイコン（`316e8d4`）**: ダーク角丸＋金色「る」。`Scripts/make-icon.swift`（CoreGraphics/CoreText で再現生成）→ `Scripts/AppIcon.icns`（コミット資産）。`CFBundleIconFile=AppIcon`、`build-app.sh` でコピー。
- **配布（M6 #12, `613b442` ほか）**: `Scripts/release.sh`（ad-hoc署名固定→非通信監査+署名検証ゲート→ditto zip→SHA-256）。**GitHub Release v0.9.0 を公開（prerelease）**。検証5点+クリーンインストールを #12 にコメント記録。#12 close。

## 2. いまの状態（State）
- ブランチ `main`、HEAD **`613b442`**、作業ツリー clean、未push無し。CI **green**。
- テスト: **Core 209 + System 8 passed**、Core カバレッジ **98%超**（閾値80%）、非通信ガード・バイナリ監査 **PASS**。
- **公開リリース**: `v0.9.0`（prerelease）= https://github.com/yyyyyyy0/rubyfree/releases/tag/v0.9.0 。資産 `rubyfree-v0.9.0-macos-arm64.zip`（ad-hoc署名・未公証）、SHA-256 `c5606cfea431cb52e3996e5cf2134db510f99a8fff8342b32b7be84ed771edbd`。タグは `613b442`。
- `~/Applications/rubyfree.app` は dev-cert ビルドで稼働中（実機確認OK。themeID=sepia 等で動作確認済）。

## 3. 決定事項（Decisions）
- **配布署名はアドホック固定**（自己署名devは他者に無意味/再現性。Developer ID 公証は$99口座要で見送り）。未公証＝右クリック→開く＋SHA-256照合で真正性担保（README記載）。
- **送り仮名は辞書ゲート必須**（宛も=語 vs 宛+も=助詞 は同じ「も」、辞書でしか判別不可）。最長一致・hiraganaのみ・上限5字。OCR経路も `VisionTextRecognizer` が漢字ランのみ抽出していたため同修正（当初「OCRは保持」と誤認＝要注意）。
- **テーマは Core(RubyTheme, CGColor)＋app境界でNSColor変換**。dark既定で従来見た目を維持（テストで RubyStyle デフォルト一致を保証）。
- **バージョン 0.9.0**（v0.9運用ゲートに対応するプレリリース。M5/M6本番は今後）。

## 4. 次にやること（Next）
1. **v0.9 ゲート（#10）**: M4実装は完了。残りは**AXのみMVPを約1週間自己使用して再評価**（運用評価）。良ければ #10 close。完了条件: 運用所見が出て #10 をclose。
2. **#5（S0-5 機内OCR）を close 可**: 本セッション②で機内モードでのVision OCR動作を実機実証済み。完了条件: #5 に実証コメントしてclose。
3. (将来) **M5（#11）**: OCRハードニング（正答率のOCR誤差対策）。安価な実験＝2倍アップスケール＋`usesLanguageCorrection` 切替の A/B（`VisionTextRecognizer`）。完了条件: A/B結果を#11に記録。
4. (任意) **#6（S0-6 AX非対応アプリ実態調査）**。完了条件: 調査結果を#6に記録 or close。

## 5. 罠・注意点（Pitfalls）
- **git add の複数パスは1つでも不存在だと全体失敗**（今回 `9fe0478` で実装本体を取りこぼし CI赤→`2a420bf`で修復）。**push 後は必ず `git show --stat` で内容確認＋CI緑を確認**すること（ローカル作業ツリーが緑でも push 内容が壊れていることがある）。
- **`set -o pipefail` + `grep -q` は SIGPIPE 誤判定**（producer が書き続けると失敗扱い）。出力を変数に取ってから grep（`release.sh` で対処済）。
- **`release.sh` は `dist/` を `rm -rf`** する。`dist/notes.md` 等を置いても消える（リリースノートは都度生成）。
- **辞書はバンドルリソース**。`build-app.sh` が `*.bundle` を `Contents/Resources/` にコピー必須（漏れると静かに `StandardAnalyzer` へ degrade、`RUBYFREE_DEBUG` の `analyzer=...` で判別）。TSV更新後は `swift Scripts/build-dict.swift ...` 再実行。
- **実機確認は固定パス `~/Applications/rubyfree.app`（`run-dev.sh`）経由**。`swift run` バイナリは別TCC主体で権限再プロンプト。run-dev は起動前に旧インスタンスを `pkill`。
- **画面収録権限は付与後に再起動が必要**（起動時評価）。**Vision `.fast` 禁止**（macOS26クラッシュ）、`.accurate`固定。
- **CFBundleIdentifier は変更厳禁**（`io.github.yyyyyyy0.rubyfree`。TCC権限がこれに紐づく）。
- **テスト**: `swift test` 不可。`swift run RubyfreeCoreTests` / `RubyfreeSystemTests`。`expectEqual` はメッセージ引数なし。
- **アイコン再生成**: `swift Scripts/make-icon.swift Scripts/AppIcon.iconset && iconutil -c icns Scripts/AppIcon.iconset -o Scripts/AppIcon.icns`（iconset は gitignore、icns はコミット）。
- **ファイル削除は trash**（rm はブロック）。

## 6. 重要リンク・参照（References）
- リポジトリ: https://github.com/yyyyyyy0/rubyfree （最新 main `613b442`）
- リリース: https://github.com/yyyyyyy0/rubyfree/releases/tag/v0.9.0
- プラン(SSOT): `/Users/nil/.claude/plans/polished-hatching-mango.md`
- プロジェクトメモリ: `/Users/nil/.claude/projects/-Users-nil-src-rubyfree/memory/rubyfree-spec.md`
- 主要ファイル（今回追加/変更）:
  - テーマ: `Sources/RubyfreeCore/Ruby/RubyTheme.swift` / `RubyAttributedBuilder.swift`(RubyStyle), `Sources/rubyfree/Overlay/RubyRenderer.swift`(chip色) / `OverlayPresenting.swift`(applyTheme) / `OverlayWindowController.swift`, `Sources/rubyfree/MenuController.swift`(テーマ+About), `Sources/RubyfreeSystem/Settings/SettingsStore.swift`(themeID)
  - 送り仮名: `Sources/RubyfreeCore/Analyze/Okurigana.swift`(CFRange/String.Index両版), `Sources/RubyfreeCore/Models/Character+Kanji.swift`(isHiragana), `Sources/RubyfreeSystem/Capture/`(AXTextCapture / VisionTextRecognizer / OCRTextCapture に辞書注入), `Sources/rubyfree/main.swift`(辞書を両経路へ共有)
  - 配布: `Scripts/release.sh` / `Scripts/build-app.sh` / `Scripts/make-icon.swift` / `Scripts/AppIcon.icns` / `Scripts/Info.plist.template`(version 0.9.0, CFBundleIconFile)
- コマンド:
  - 実機起動: `./Scripts/run-dev.sh`
  - 検証(canonical): `./Scripts/pre-push.sh`
  - リリース生成: `./Scripts/release.sh`（dist/ に zip+sha 生成、publish はしない）
  - 個別テスト: `swift run RubyfreeCoreTests` / `swift run RubyfreeSystemTests`
  - デバッグ観測: `RUBYFREE_DEBUG=1 ~/Applications/rubyfree.app/Contents/MacOS/rubyfree`（ログは len/offset/座標のみ・生テキスト非出力）
- Issues: **#12(M6配布) closed** / **#13(テーマ) closed** / #11(M5 OCR) open / #10(M4 v0.9運用ゲート) open / #6(S0-6) open / #5(S0-5 機内OCR=実証済, close可) open。

## Changelog
- 2026-06-11: v0.9.0 公開（prerelease, ad-hoc署名）。M6検証5点+クリーンインストールを #12 記録しclose `613b442`。
- 2026-06-11: アプリアイコン（金「る」）`316e8d4` / About パネル（権利表記）`ca84def`。
- 2026-06-11: 漢字＋送り仮名を辞書ゲートでまとめ読み（宛も→あたかも、AX/OCR両経路）`2a420bf`（実装本体取りこぼし `9fe0478`→修復）。
- 2026-06-11: テーマ8種選択 `ecaec09`、#13 close。
- 2026-06-11: M4実装（メニューON/OFF・権限喪失検出・設定永続）`8e64da7`、#9 close（前セッション）。
