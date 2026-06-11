# HANDOVER

Updated: 2026-06-11 JST

rubyfree = マウスホバーで画面上の漢字にふりがな（ルビ）を透明オーバーレイ表示する macOS 常駐ユーティリティ（完全ローカル・非通信・個人開発OSS）。

## 1. このセッションで完了したこと（Done）
- **読み解析を辞書ベースに刷新**（`DictionaryAnalyzer`）。`CFStringTokenizer` の単一読み・難読誤りを脱し、**JMdict 224,686語 + kanjidic2 12,272字** の最長一致解析へ。海月→くらげ、紫陽花→あじさい、向日葵→ひまわり 等が正答。
- **複数読み表示**: `Reading.alternatives` / `RubyRun.alternatives` を追加し、Composer→Builder で `主／代／…`（全角スラッシュ連結）で複数候補を表示。複数読み語は `isUncertain` で減光。
- **MeCab を採用せず純Swiftに決定**（理由は Decisions）。**ランタイム完全オフライン維持**（辞書は `Bundle.module` のローカルTSV）。
- **再現可能な辞書生成**: `Scripts/fetch-dict-sources.sh`（EDRDGからJMdict/kanjidic2を**ビルド時1回だけ**取得→`.dict-cache/`、gitignore）→ `Scripts/build-dict.swift`（XMLParserで漢字見出しのみ抽出・カタカナ→ひらがな正規化・`re_restr`尊重・最大6読み）→ `Sources/RubyfreeCore/Resources/{words,kanji}.tsv`（~7.4MB、コミット済）。
- **`.app` への辞書同梱**: `Package.swift` に resources 宣言、`build-app.sh` が `*.bundle` を `Contents/Resources/` へコピー。実機 `.app` で辞書ロード確認済（debugログ `analyzer=DictionaryAnalyzer words=224686`）。
- **ライセンス**: `NOTICE` 追加。コードは MIT、辞書データは EDRDG **CC-BY-SA 4.0** と明記して両立。
- テスト: `DictionaryAnalyzerTests`（最長一致・複数読み・フォールバック・空辞書防御・TSV往復・**バンドル辞書 end-to-end**）追加。**Core 153 + System 1 green**、カバレッジ **97.45%**、非通信ガード/バイナリ監査PASS。コードレビュー実施（CRITICAL/HIGHなし、指摘#3反映＝レンダラを `allReadings` 経由に）。

## 2. いまの状態（State）
- ブランチ `main`。コミット直後（本セッションのコミットハッシュは `git log` 参照）。
- `~/Applications/rubyfree.app` は辞書ビルドで稼働中。AX対応アプリ＝AX、TextEdit/Web＝OCRフォールバック、どちらも辞書解析。
- 権限: AX付与済み。**画面収録は本セッションで再付与プロンプトが出た**（ScreenCaptureKitの「プライベートウインドウピッカーをバイパス」標準プロンプト＝意図通り）。付与後は**要再起動**でOCR有効。音声は一切キャプチャしない（SCのTCCが画面+音声を束ねるだけ）。
- ユーザー実機評価: 「まあまあ」。速度は良好。**残課題3件**（下記 Next 1–3）。

## 3. 決定事項（Decisions）
- **辞書は純Swift + JMdict/kanjidic2、MeCab+UniDicは不採用**。理由: ①MeCabのC++ソースは `mecab-server`（socket/`getaddrinfo`）を含み**非通信ガード/ハード要件と衝突** ②辞書バイナリのビルドが外部ツール依存で**再現困難** ③C++×Swift6相互運用コスト。純Swiftなら非通信をクリーンに満たし、**複数読み表示**（ユーザー要望）にもJMdictが自然に適合。トレードオフ＝文法コストモデルが無く走り書き文中の語境界精度はMeCab劣後（活用語＝食べた等は単漢字フォールバックになりがち）。実害は小さいと判断（読みの正誤は辞書依存・本アプリは語窓を切出済）。
- **複数読み語は `isUncertain=true`**（あいまい＝減光表示）。単漢字フォールバックも常に uncertain。
- **生成TSVをリポジトリにコミット**（クリーン環境でダウンロード無しにビルド可能＝再現性/オフライン優先。容量はユーザー許容）。

## 4. 次にやること（Next）— 実機評価で出た残課題
1. **読み正答率の改善**（Wikipedia難読漢字で「まちまち」）。仮説: ①捕捉スパンが辞書見出しと不一致（AX語拡張/OCR箱が余計なかな込み・複合語を分割）②JMdictの第1読みが当該surfaceの常用読みと限らない（出現順≠頻度順）③熟字訓×送り仮名。次の一手: `RUBYFREE_DEBUG` で `captured.text` と採用読みをログ化し**失敗例を具体収集**してから調整（盲目的修正は避ける）。完了条件: 収集した失敗例セットで正答率が目に見えて改善。
2. **セキュアフィールド非表示の実機確認**（M3残）。完了条件: パスワード欄ホバーで何も出ない → **issue #9 close**。
3. (任意)テーマ/カラーパレット選択のbacklog化。M4着手(issue#10): メニュー拡充・PermissionsManager・Settings永続化。

### 解決済み（Resolved）
- **複数読みルビの重なり**（実機「よくなった」確認済）。`RubyAttributedBuilder` の CTRubyAnnotation overhang を `.auto`→`.none`（幅広ルビが隣接ラン/漢字へはみ出さず基底側が幅確保）、`RubyStyle.maxReadings`（既定3）で表示候補を間引き（モデルは全候補保持）。`CTRubyAnnotationGetTextForPosition` でルビ文字列を実読み出し検証。
- **チップ残留**（実機「よさげ」確認済）。`AppCoordinator.handleMoved` で移動時に `captureTask?.cancel()` + `generation` バンプ + 無条件 `overlay.hide()`、`failCapture` でも hide、セキュア欄抑止も `failCapture` 経由に統一。旧位置キャプチャの遅延表示と fail 時の残留を根絶。
- **run-dev の旧プロセス残留**: `run-dev.sh` が `open` で既存インスタンスを再アクティブ化するだけで新バイナリに差し替わらず、修正が反映されない罠があった。起動前に `pkill` + `open -n` へ修正。

## 5. 罠・注意点（Pitfalls）
- **辞書はバンドルリソース**。`Bundle.module` 解決のため `build-app.sh` が `*.bundle` を `Contents/Resources/` にコピー必須（漏れると静かに `StandardAnalyzer` へ degrade、debugログで判別可）。生成TSVを更新したら `swift Scripts/build-dict.swift .dict-cache/JMdict_e.xml .dict-cache/kanjidic2.xml Sources/RubyfreeCore/Resources` を再実行。
- **辞書ソースの再取得は `Scripts/fetch-dict-sources.sh`**（外向き通信はここだけ・ビルド時のみ）。`.dict-cache/` はgitignore。
- **AXは座標→語マッピング不可なアプリが多い**（TextEdit/Web）→OCR頼み。**Vision `.fast` 禁止**（macOS26クラッシュ）、`.accurate`固定、画像は最小サイズ確保。
- **画面収録権限**: 付与後は再起動が必要。`swift run`バイナリは別TCC主体なので実機確認は固定パス `~/Applications/rubyfree.app`（`run-dev.sh`）経由。
- **署名**: 自己署名cert `rubyfree-dev`（cdhash非依存DRで権限保持）。新環境は先に `setup-dev-cert.sh`。
- **テスト**: `swift test`は不可。`swift run RubyfreeCoreTests`/`RubyfreeSystemTests`。`expectEqual`はメッセージ引数なし。
- **ファイル削除はtrash**（rmはブロック）。
- **非通信ガード**: `pre-push.sh` が `Sources/` を `URLSession|import Network|CFSocket|NWConnection|getaddrinfo` でgrep。

## 6. 重要リンク・参照（References）
- リポジトリ: https://github.com/yyyyyyy0/rubyfree
- プラン(SSOT): `/Users/nil/.claude/plans/polished-hatching-mango.md`
- 主要ファイル（今セッション）:
  - `Sources/RubyfreeCore/Analyze/`(DictionaryAnalyzer / ReadingDictionary / BundledDictionary / JapaneseAnalyzing / StandardAnalyzer[=保険])
  - `Sources/RubyfreeCore/Models/`(Reading[+alternatives,allReadings] / RubyRun[+alternatives])
  - `Sources/RubyfreeCore/Compose/RubyComposer.swift`(allReadings経由), `Ruby/RubyAttributedBuilder.swift`(主／代表示)
  - `Sources/rubyfree/main.swift`(辞書優先・StandardAnalyzerフォールバック・debugログ), `AppCoordinator.swift`(Next#1の修正対象)
  - `Scripts/`(fetch-dict-sources.sh / build-dict.swift / build-app.sh[resourceコピー])
  - `Sources/RubyfreeCore/Resources/{words,kanji}.tsv`, `NOTICE`
- コマンド:
  - 実機起動: `./Scripts/run-dev.sh`
  - 辞書再生成: `./Scripts/fetch-dict-sources.sh` →（出力された）`swift Scripts/build-dict.swift ...`
  - デバッグ観測: `RUBYFREE_DEBUG=1 nohup ~/Applications/rubyfree.app/Contents/MacOS/rubyfree > /tmp/rubyfree-debug.log 2>&1 &`
  - 検証: `./Scripts/pre-push.sh`（build/tests/非通信ガード/coverage/binary audit）
- Issues(open): #5(S0-5機内), #6(S0-6 AX実態), #9(M3 セキュア欄確認のみ残), #10(M4), #11(M5一部前倒し済), #12(M6)。

## Changelog
- 2026-06-11: 複数読みルビの重なり解消（overhang無効化＋表示上限maxReadings=3）。run-dev.sh の旧プロセス残留も修正。実機「よくなった」確認。
- 2026-06-11: チップ残留バグ修正（移動時の捕捉キャンセル+generation更新+無条件hide、fail経路hide）。実機「よさげ」確認。
- 2026-06-11: 読み解析をJMdict/kanjidic2辞書ベースへ刷新＋複数読み表示。純Swift・非通信維持・再現可能生成。Core 153+1緑/97.45%。実機評価「まあまあ」、残課題3件（チップ残留/ルビ重なり/正答率）をNextに記録。
- 2026-06-11: M3を実動状態へ（座標バグ修正・AX単語抽出・OCRフォールバック・オーバーレイ刷新）。`ed2fd2d` push・CI green。
- 2026-06-10: M3 AXパイプライン+オーバーレイ コア実装（Fake E2E成功）。
