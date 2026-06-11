# HANDOVER

Updated: 2026-06-11 JST

rubyfree = マウスホバーで画面上の漢字にふりがな（ルビ）を透明オーバーレイ表示する macOS 常駐ユーティリティ（完全ローカル・非通信・個人開発OSS / MIT）。

## 1. このセッションで完了したこと（Done）
本日 main に 5 コミット（全て push 済み・CI green）。M3 を実用品質へ磨き、M4 を実装。
- **辞書ベースの読み解析へ刷新**（`8bd3cd7`）: `DictionaryAnalyzer`＝JMdict 224,686語＋kanjidic2 12,272字の最長一致。難読・熟字訓を正答（海月→くらげ等）。`Reading.alternatives`/`RubyRun.alternatives` で**複数読み表示**（`主／代` 形式）。辞書はバンドルTSV（`Bundle.module`、~7.4MB、ランタイム完全オフライン）。生成は再現可能（`fetch-dict-sources.sh`→`build-dict.swift`）。
- **チップ残留バグ修正**（`d49f648`）: 移動時に in-flight `captureTask` をキャンセル＋`generation`バンプ＋無条件`hide()`、`failCapture`でも hide。旧位置キャプチャの遅延表示を根絶。
- **複数読みルビの重なり修正**（`246ab25`）: CTRubyAnnotation overhang を `.none` 化＋`RubyStyle.maxReadings`（既定3）。`run-dev.sh` の旧プロセス残留（`open`が新バイナリに差し替わらない罠）も `pkill`+`open -n` で修正。
- **3字以上の熟語まとめグロス＋セキュア検出マルチモニタ修正**（`42b50a4`）: 捕捉単位を `CFStringTokenizer` 語境界→**連続漢字ラン**（新Core `KanjiRun`）に変更（経済学が経済|学に割れない）。AX/OCR両経路で採用。`AXSecureFieldDetector` のy反転を `NSScreen.main`→**プライマリ画面基準**へ（多モニタでパスワード欄取りこぼしリスクだった）。
- **M4 常駐・権限フロー・設定**（`8e64da7`）: 下記 §4 解決済み参照。

## 2. いまの状態（State）
- ブランチ `main`、HEAD **`8e64da7`**、未push無し・作業ツリー clean。CI **green**（core ジョブ）。
- テスト: **Core 171 + System 5 passed**、Core カバレッジ **97.96%**（閾値80%）、非通信ガード・バイナリ監査 **PASS**（ScreenCaptureKit/Vision/AppKitのみリンク・ネット系シンボル無し）。
- `~/Applications/rubyfree.app` は M4 ビルドで稼働中（実機「動作確認おｋ」）。
- 権限: AX・画面収録とも付与済み。OCRは画面収録付与後の**再起動**で有効。
- 動作: AX対応アプリ=AX語/熟語抽出、TextEdit/ブラウザ=OCRフォールバック。メニューでON/OFF・権限状態・設定で開く。

## 3. 決定事項（Decisions）
- **辞書は純Swift+JMdict/kanjidic2、MeCab+UniDic不採用**。理由: ①MeCab C++ソースが `mecab-server`(socket/`getaddrinfo`)を含み**非通信ハード要件と衝突** ②辞書バイナリのビルドが外部ツール依存で再現困難 ③C++×Swift6相互運用コスト。純Swiftで非通信を満たしつつ複数読み表示にも適合。
- **生成TSVをコミット**（クリーン環境でDL無しビルド可＝再現性/オフライン優先。容量はユーザー許容）。データは EDRDG **CC-BY-SA 4.0**（`NOTICE` で帰属、コードは MIT）。
- **グロス単位＝連続漢字ラン**（トークナイザ語ではなく）。熟語を割らず辞書最長一致を活かす。
- **複数読み語/単漢字フォールバックは `isUncertain`**（減光表示）。表示は最大3候補。
- **正答率「まちまち」はOCR認識誤差が主因と切り分け済**（辞書は代表難読40語中39語第1読み正解・欠落0）。ユーザー合意の上で受容（M5でハードニング）。
- **セキュア欄はネイティブ `AXSecureTextField` のみ確実**。ブラウザAX判定は保証外だが、生パスワードは伏字レンダリングで構造的に非露出（後回し合意）。

## 4. 次にやること（Next）
1. **v0.9 ゲート（issue#10）**: M4実装は完了。残るは受入の最後＝**AXのみMVPを約1週間自己使用して再評価**（運用評価・コード作業ではない）。目安 ~2026-06-18 以降。良ければ #10 close。
2. (任意) テーマ/カラーパレット選択の backlog 化（ユーザー将来要望）。完了条件: issue化 or プラン追記。
3. (将来) **M5**: OCRハードニング（正答率のOCR誤差対策）。安価な実験候補＝2倍アップスケール＋`usesLanguageCorrection` 切替を `VisionTextRecognizer` で A/B。M6。

✅ issue #9 (M3) は close 済み。#10 (M4) は実装完了コメント済み・v0.9運用ゲート待ちで open。

### 解決済み（このセッション、Resolved）
- **M4 常駐・権限フロー・設定**（実機確認OK）: `MenuController`（main.swiftから抽出、ON/OFFトグル+権限状態+「設定で開く…」、NSMenuDelegateで開く度+`onStateChange`で更新）。`AppCoordinator.setEnabled`（OFF→`monitor.stop()`でCPU静音・overlay hide・task cancel、アイコン減光）。2秒間隔の権限ポーリングで実行中喪失検出→needsPermission・回復で復帰（手動OFFは尊重）。`UserDefaultsSettingsStore`（設定値`isEnabled`のみ永続・ユーザーデータ非保持）。LSUIElementでDockレス。
- 3字熟語まとめ / 複数読み重なり / チップ残留 / セキュア検出マルチモニタ / run-dev旧プロセス残留（各§1参照）。

### Known limitations / Deferred（合意済み）
- 読み正答率「まちまち」=OCR誤認識（例 父→夫）。誤読は減光表示。本格対策はM5。
- ブラウザのセキュアフィールドAX判定は保証外（生パスワードは非露出）。ユーザーが「パスワード表示」で平文化した場合のみ残エッジ。

## 5. 罠・注意点（Pitfalls）
- **辞書はバンドルリソース**。`build-app.sh` が `*.bundle` を `Contents/Resources/` にコピー必須（漏れると静かに `StandardAnalyzer` へ degrade、`RUBYFREE_DEBUG` ログ `analyzer=...` で判別）。TSV更新後は `swift Scripts/build-dict.swift .dict-cache/JMdict_e.xml .dict-cache/kanjidic2.xml Sources/RubyfreeCore/Resources` 再実行。
- **辞書ソース再取得は `fetch-dict-sources.sh`** が唯一の外向き通信（ビルド時のみ）。`.dict-cache/` は gitignore。
- **実機確認は固定パス `~/Applications/rubyfree.app`（`run-dev.sh`）経由**。`swift run` バイナリは別TCC主体で権限再プロンプトになる。`run-dev.sh` は起動前に旧インスタンスを `pkill`（古いビルドが残ると修正が反映されない罠を回避）。
- **画面収録権限は付与後に再起動が必要**（起動時評価）。**Vision `.fast` 禁止**（macOS26クラッシュ）、`.accurate`固定、画像は最小サイズ確保。
- **AXは座標→語マッピング不可なアプリが多い**（TextEdit/WebKit）→OCR頼み。仕様（隠しAX技は無い）。
- **署名**: 自己署名cert `rubyfree-dev`（cdhash非依存DRで権限保持）。新環境は先に `setup-dev-cert.sh`。
- **テスト**: `swift test` 不可。`swift run RubyfreeCoreTests`/`RubyfreeSystemTests`。`expectEqual` はメッセージ引数なし（`expectTrue` はあり）。
- **ファイル削除は trash**（rm はブロック）。

## 6. 重要リンク・参照（References）
- リポジトリ: https://github.com/yyyyyyy0/rubyfree （最新 main `8e64da7`）
- プラン(SSOT): `/Users/nil/.claude/plans/polished-hatching-mango.md`
- プロジェクトメモリ: `/Users/nil/.claude/projects/-Users-nil-src-rubyfree/memory/rubyfree-spec.md`
- 主要ファイル:
  - 解析: `Sources/RubyfreeCore/Analyze/`(DictionaryAnalyzer / ReadingDictionary / BundledDictionary / KanjiRun / WordBoundary / StandardAnalyzer[保険] / JapaneseAnalyzing)
  - モデル: `Sources/RubyfreeCore/Models/`(Reading[+alternatives,allReadings] / RubyRun / AnalyzedToken / PermissionStatus)
  - 描画: `Sources/RubyfreeCore/Ruby/RubyAttributedBuilder.swift`(RubyStyle: overhang.none, maxReadings), `Sources/rubyfree/Overlay/`(RubyRenderer 黒チップ / OverlayWindowController)
  - 捕捉: `Sources/RubyfreeSystem/Capture/`(AXTextCapture / VisionTextRecognizer / ScreenRegionCapture / OCRTextCapture / AXSecureFieldDetector / TextCapturing)
  - 常駐/UI: `Sources/rubyfree/`(main.swift 結線 / AppCoordinator 状態機械+enable+権限ポーリング / MenuController)
  - 入力/権限/設定: `Sources/RubyfreeSystem/`(Input/PollingMouseMonitor / Permissions/AXPermissionChecker / Settings/UserDefaultsSettingsStore)
- コマンド:
  - 実機起動: `./Scripts/run-dev.sh`
  - 辞書再生成: `./Scripts/fetch-dict-sources.sh` → 出力された `swift Scripts/build-dict.swift ...`
  - 検証(canonical): `./Scripts/pre-push.sh`（build/tests/非通信ガード/coverage/binary audit）
  - 個別テスト: `swift run RubyfreeCoreTests` / `swift run RubyfreeSystemTests`
  - デバッグ観測: `RUBYFREE_DEBUG=1 nohup ~/Applications/rubyfree.app/Contents/MacOS/rubyfree > /tmp/rubyfree-debug.log 2>&1 &`
- Issues: #9(M3) **closed** / #10(M4) open=v0.9運用ゲート待ち / #11(M5 OCR) / #12(M6) / #5,#6(S0)。

## Changelog
- 2026-06-11: M4実装（メニューON/OFF・権限喪失検出ポーリング・設定永続・MenuController抽出）`8e64da7`。#9 close。残v0.9=1週間自己使用。
- 2026-06-11: 3字以上熟語まとめグロス（KanjiRun）＋セキュア検出マルチモニタ修正 `42b50a4`。正答率まちまち=OCR誤差と切り分け。
- 2026-06-11: 複数読みルビ重なり解消（overhang無効化＋maxReadings=3）＋run-dev旧プロセス対策 `246ab25`。
- 2026-06-11: チップ残留バグ修正 `d49f648`。
- 2026-06-11: 読み解析をJMdict/kanjidic2辞書ベースへ刷新＋複数読み表示 `8bd3cd7`（純Swift・非通信維持・再現可能生成）。
- 2026-06-11: M3を実動状態へ（座標バグ修正・AX単語抽出・OCRフォールバック・オーバーレイ刷新）`ed2fd2d`。
- 2026-06-10: M3 AXパイプライン+オーバーレイ コア実装（Fake E2E成功）。
