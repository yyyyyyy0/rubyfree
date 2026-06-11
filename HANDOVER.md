# HANDOVER

Updated: 2026-06-11 JST

rubyfree = マウスホバーで画面上の漢字にふりがな（ルビ）を透明オーバーレイ表示する macOS 常駐ユーティリティ（完全ローカル・非通信・個人開発OSS）。

## 1. このセッションで完了したこと（Done）
- **M3を「実際に動く」状態へ**（コミット `ed2fd2d`、push済み・CI green）。実機ホバーで語単位ふりがな表示を確認。
- **🐛 マルチモニタ座標バグ修正**: AppKit↔AXのY反転を `NSScreen.screens`のunion高さ → **プライマリ画面(origin(0,0))の高さ**基準に変更。プライマリより上下に張り出す副ディスプレイがあると、その張り出し分（開発機で1152px）が全ヒットテストに乗り、座標が大きくズレていた。`AXTextCapture.swift`＋`CoordinateConverter.swift`のdoc修正。
- **✅ AX単語抽出に刷新** (`AXTextCapture.swift`): `AXRangeForPosition`→カーソルindex→`WordBoundary`(新Core純ロジック, ja_JP語境界)→`AXStringForRange`/`AXBoundsForRange`。不正range（≤0/>64/≒Int64.max のゴミ値）を拒否。**全文AXValueフォールバックを撤廃**（「一行全部出る」の原因だった）。
- **✅ OCRフォールバック実装** (新規3ファイル): `ScreenRegionCapture`(ScreenCaptureKitで領域キャプチャ) + `VisionTextRecognizer`(`.accurate`/ja+en/プリウォーム/語ボックス選択) + `OCRTextCapture`(TextCapturing)。`main.swift`で`TextCaptureStrategy(primary:AX, fallback:OCR)`に結線、画面収録権限でゲート。
- **🎨 オーバーレイ刷新**: 黒チップ(#141414/92%/白枠) + **明るいアンバーのふりがな** + 拡大(base22pt/ruby0.6×) + ルビgap(`kCTBaselineOffsetAttributeName`) + カーソル回避(語の10pt上)。不確実な読みはふりがなのみ減光（基底は白で可読維持）。
- **診断**: `RUBYFREE_DEBUG` 環境変数でstderrログ(`DebugLog.swift`、既定off)。
- テスト: `WordBoundaryTests`追加。`RubyAttributedBuilderTests`の色コントラクト更新（基底は常にforeground、不確実はrubyで表現）。**Core 124 + System 1 green**。

## 2. いまの状態（State）
- ブランチ `main`、最新 **ed2fd2d**、push済み・未push無し。CI **green**(macos-26, 1m8s)。
- 実機動作: **AX対応アプリ=AX単語抽出 / TextEdit・Web等=OCRフォールバック**で語単位ふりがな表示を確認済み。座標・チップ表示OK。
- `~/Applications/rubyfree.app` は最新版で稼働中（パディング入り）。`RUBYFREE_DEBUG=1`の前景バイナリをnohup起動して観測している（ログ `/tmp/rubyfree-debug.log`）。
- 権限: AX・**画面収録(Screen Recording)** とも付与済み。画面収録は付与後に再起動でOCR有効化される（初回起動セッションでは無効＝再起動が必要）。
- **既知の品質課題**: ①OCR信頼度0.3が多い（=Vision文字認識の確信度。読みの正誤とは無関係）②難読漢字で読み誤り（標準辞書の限界、下記Decisions）。

## 3. 決定事項（Decisions）
- **OCR前倒し採用（M5→M3に実装）**: TextEdit(NSTextView)等は `AXRangeForPosition`/`AXBoundsForRange` 非対応で「座標→語」がAX原理的に不可能（属性一覧で実証）。Webは`AXTextMarker`系の別API。汎用の語特定はOCRのみ。実測でOCR `.accurate` warm≈**160ms**・安定、`.fast`は`CRTextDetectorModelV3`が**毎回クラッシュ**するため`.accurate`固定。極小/極端アスペクト比の画像もVisionがクラッシュするため領域は280×140pt以上を確保。
- **軽量さはクリップ縮小でなくデバウンスで担保**: コスト支配項はVision推論(固定~160ms)で画素数非依存。ホバー静止時1回・actor相当のnonisolated async（off-main）で実行。
- **キャプチャ系はactor→struct(nonisolated async)**: `SCShareableContent`等が非Sendableでactor境界を越えられないため。nonisolated asyncはMainActorから呼んでもグローバルExecutorで実行されオフメイン維持。
- **辞書（次の判断、ユーザー未確定）**: 推奨=**MeCab+UniDic導入**（実行時数十μsで軽量、熟字訓含む高精度、`JapaneseAnalyzing`プロトコル背後に差し替え）→第2段でkanjidic2/JMdictにより複数読み表示。ユーザーは「動作が軽量なら容量は気にしない」。**この方向でGoかどうか次セッション冒頭で要確認**。

## 4. 次にやること（Next）
1. **辞書方針のGo確認 → MeCab+UniDic を `JapaneseAnalyzing` 実装として導入**。完了条件: 海月→くらげ等の難読が正しく読め、既存パイプライン無改修で差し替わる。
2. **複数読み表示**: `Reading`を候補リスト化＋composer/builder/renderer対応（kanjidic2 or JMdict）。完了条件: 複数読みを持つ語で候補が並んで表示される。
3. **セキュアフィールド非表示の実機確認**（M3残）。完了条件: パスワード欄ホバーで何も出ない。確認後 **issue #9 close**。
4. (任意)**テーマ/カラーパレット選択**のbacklog化（今回未着手、ユーザー要望）。完了条件: issue化 or プラン追記。
5. **M4着手**(issue#10): メニュー拡充(ON/OFF・権限状態)、PermissionsManager案内+ポーリング、Settings永続化。完了条件: プランM4受入基準 + v0.9自己評価。

## 5. 罠・注意点（Pitfalls）
- **AXは座標→語マッピングが取れないアプリが多い**（TextEdit/Web）。AX対応は「ネイティブ静的テキスト等」のみ、それ以外はOCR頼み。これは仕様（隠しAX技は無い）。
- **Vision `.fast` 禁止**（macOS26でクラッシュ）。`.accurate`固定。画像は最小サイズ確保（極小でクラッシュ）。
- **画面収録権限**: 付与後は再起動が必要（`CGPreflightScreenCaptureAccess()`は起動時評価）。`swift run`バイナリは別TCC主体なので実機確認は固定パス`~/Applications/rubyfree.app`経由（`run-dev.sh` or バンドル内バイナリ直接実行）。
- **署名**: 自己署名cert `rubyfree-dev` で署名（cdhash非依存DRで権限保持）。`build-app.sh`が自動選択、無ければアドホックfallback(権限リセット注意)。新環境は先に `setup-dev-cert.sh`。
- **テスト**: `swift test`は動かない。`swift run RubyfreeCoreTests`/`RubyfreeSystemTests`。`expectEqual`はメッセージ引数なし（`expectTrue`はあり）。
- **ファイル削除はtrash**（rmはブロック）。
- **非通信ガード**: `pre-push.sh`が`URLSession|import Network|CFSocket|NWConnection|getaddrinfo`をgrep。ScreenCaptureKit/Visionは該当せずOK。

## 6. 重要リンク・参照（References）
- リポジトリ: https://github.com/yyyyyyy0/rubyfree （最新 main `ed2fd2d`）
- プラン(SSOT): `/Users/nil/.claude/plans/polished-hatching-mango.md`
- プロジェクトメモリ: `/Users/nil/.claude/projects/-Users-nil-src-rubyfree/memory/rubyfree-spec.md`
- 主要ファイル（今セッション）:
  - `Sources/RubyfreeSystem/Capture/`(AXTextCapture / ScreenRegionCapture / VisionTextRecognizer / OCRTextCapture / TextCapturing[=TextCaptureStrategy])
  - `Sources/RubyfreeCore/Analyze/WordBoundary.swift`, `Sources/RubyfreeCore/Ruby/RubyAttributedBuilder.swift`(RubyStyle)
  - `Sources/rubyfree/Overlay/`(RubyRenderer=黒チップ / OverlayWindowController=配置+gap), `Sources/rubyfree/main.swift`(結線)
  - `Sources/RubyfreeSystem/DebugLog.swift`
- コマンド:
  - 実機起動: `./Scripts/run-dev.sh`（固定パス配置+open）
  - デバッグ観測: `RUBYFREE_DEBUG=1 nohup ~/Applications/rubyfree.app/Contents/MacOS/rubyfree > /tmp/rubyfree-debug.log 2>&1 &`
  - 検証: `./Scripts/pre-push.sh`（build/tests/非通信ガード/coverage/binary audit）
  - 個別: `swift run RubyfreeCoreTests` / `swift run RubyfreeSystemTests` / `./Scripts/coverage.sh`
- Issues(open): #5(S0-5機内), #6(S0-6 AX実態), #9(M3 セキュア欄確認のみ残), #10(M4), #11(M5=OCR本実装/権限JIT—一部前倒し済), #12(M6)。

## Changelog
- 2026-06-11: M3を実動状態へ（座標バグ修正・AX単語抽出・OCRフォールバック・オーバーレイ刷新）。`ed2fd2d` push・CI green。辞書方針はユーザー判断待ち。
- 2026-06-10: M3 AXパイプライン+オーバーレイ コア実装（Fake E2E成功）。
