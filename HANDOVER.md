# HANDOVER

Updated: 2026-06-10 JST

rubyfree = マウスホバーで画面上の漢字にふりがな（ルビ）を透明オーバーレイ表示する macOS 常駐ユーティリティ（完全ローカル・非通信・個人開発OSS）。

## 1. このセッションで完了したこと（Done）
- 計画フェーズ: 要件確定 → 3者レビュー(mob-critic/architect/security) → Fableメタ統合 → **プランv2承認**。
- **S0スパイク 5/6 完了**: S0-1署名(自己署名cert採用), S0-2入力(ポーリング), S0-3描画(AppKit標準でルビOK), S0-4読み精度(95%超), S0-5 OCR(オンライン動作)。
- **M1 基盤 完了/close**: SwiftPM 3ターゲット(RubyfreeCore/RubyfreeSystem/rubyfree)、自前TinyTest、Scripts、CI(macos-26 green)、非通信多層防御、自己署名cert署名。
- **M2 Core純ロジック 完了/close**: StandardAnalyzer/HoverReducer/CoordinateConverter/AppStateReducer/RubyComposer/RubyAttributedBuilder/CapturedTextサニタイズ。**116テスト・カバレッジ97.92%**。
- **M3 AXパイプライン+オーバーレイ コア実装**: AppCoordinator(Composition Root) + AXTextCapture(actor) + PollingMouseMonitor + AXPermissionChecker + AXSecureFieldDetector + OverlayWindowController + RubyRenderer + FakeTextCapture。main.swift結線。**Fakeモードで実機E2E成功**(ふりがな表示・移動で消去・クリックスルー)。

## 2. いまの状態（State）
- ブランチ `main`、最新コミット **9796aac**(M3)、**push済み・未push無し**。
- CI: macos-26 runner で Core テスト+カバレッジ80%ゲート+grepガード。M2まで green 実績。M3 push分は `gh run list` で要確認(Coreのみなので通る見込み)。
- 動作: **Fakeモード(`RUBYFREE_FAKE_CAPTURE=1 swift run rubyfree`)でE2E確認済み**。**実AXモードは未確認**。
- `~/Applications/rubyfree.app` は M1 skeleton版(古い)。M3版へ未更新 → 実AX確認時に `run-dev.sh` で更新が必要。
- 自己署名cert `rubyfree-dev` は login keychain に作成済み(`setup-dev-cert.sh` 冪等)。AX権限は付与済みだが TCC reset を挟んだので実AX版起動時に再付与の可能性あり。

## 3. 決定事項（Decisions）
- **署名=ローカル自己署名cert(`rubyfree-dev`)**。アドホックはcdhashベースDRでリビルド毎に権限リセット(S0-1実証)。自己署名はDR=identifier+cert leafでcdhash非依存→保持。
- **読み=macOS標準API**(CFStringTokenizer+CFStringTransform)。S0-4で常用語96.8%、MeCab前倒し不要。`isUncertain`は同形異音語リストで判定(NLTaggerは単語単体で固有名詞検出不可)。
- **描画=AppKit標準`NSAttributedString.draw`**(S0-3で実証、手動CTLineDraw不要)。座標はCTLine実測。
- **入力=`NSEvent.mouseLocation`ポーリング**(S0-2、グローバルモニタは権限要・silent fail)。
- **テスト=自前TinyTest**(Command Line ToolsにXCTest/swift-testing無し)。`swift test`は不可。
- **並行性**: `generation`横断統一でstale破棄、`@MainActor AppCoordinator`、AX取得は`actor`でoffload・`AXUIElement`を境界跨がせない。
- App Sandbox不採用(他アプリAXと両立せず)、非サンドボックス+Hardened Runtime、`network.client`エンタイトルメント不付与。

## 4. 次にやること（Next）
1. **実AX確認**: `RUBYFREE_INSTALL_DIR`既定のまま `./Scripts/run-dev.sh` でM3版を`~/Applications`へ再配置・起動 → AX権限(再付与あれば許可) → TextEditに日本語入力しホバー。完了条件: **実際の漢字にふりがなオーバーレイが出る**。
2. **セキュアフィールド非表示確認**: ログイン画面/パスワード欄でホバー → 何も出ない。完了条件: **セキュア欄で非表示**。
3. **M3 issue #9 をclose**。完了条件: 上記1,2が確認済み。
4. (任意)**S0-5機内モード**(issue#5: Wi-Fi切断で `swift Spikes/s0-5-ocr.swift` 再実行)、**S0-6 AX実態**(issue#6: Safari/Chrome/PDFでAX取得可否)。完了条件: 各issueに判定記録。
5. **M4着手**(issue#10, 常駐・権限フロー・設定 v0.9): メニュー拡充(ON/OFF・権限状態)、PermissionsManager案内+ポーリング、Settings(UserDefaults・設定値のみ)永続化。完了条件: プランM4受入基準(OFFで監視ハンドル解放/権限フロー全経路/再起動後設定保持) + v0.9自己評価。

## 5. 罠・注意点（Pitfalls）
- **署名**: 必ず自己署名cert で署名する。`build-app.sh`は `security find-certificate -c rubyfree-dev` で自動選択(無ければアドホックfallback→権限リセットするので注意)。新環境では先に `./Scripts/setup-dev-cert.sh`。
- **テスト**: `swift test` は動かない。`swift run RubyfreeCoreTests` / `swift run RubyfreeSystemTests`。カバレッジは `Scripts/coverage.sh`(`RUBYFREE_COV_MIN`で閾値、M2以降80)。
- **TCC主体**: 実AX確認は必ず固定パス`~/Applications/rubyfree.app`(run-dev.sh経由)で。`swift run`バイナリは別TCC主体(=AX権限が効かない)。ただしFakeモードはAX不要なので`swift run`でOK。
- **PKCS12**: Homebrew openssl 3.x のp12は`security`が読めない→`/usr/bin/openssl`(LibreSSL)+**非空パスワード**必須(setup-dev-cert.shで対応済)。
- **Swift 6 concurrency**: `kAX...`定数はconcurrency-unsafe→文字列リテラル("AXStringForRange"等)で回避。`@MainActor`classがprotocol準拠時は `: @MainActor ProtocolName`。
- **ファイル削除はtrash**(rmはブロック)。

## 6. 重要リンク・参照（References）
- リポジトリ: https://github.com/yyyyyyy0/rubyfree
- プラン(SSOT): `/Users/nil/.claude/plans/polished-hatching-mango.md`
- プロジェクトメモリ: `/Users/nil/.claude/projects/-Users-nil-src-rubyfree/memory/rubyfree-spec.md`
- 主要ファイル:
  - `Sources/rubyfree/AppCoordinator.swift`(結線・generation), `Sources/rubyfree/main.swift`, `Sources/rubyfree/Overlay/`(OverlayWindowController/RubyRenderer/OverlayPresenting)
  - `Sources/RubyfreeCore/`(Models/Analyze/Hover/State/Compose/Ruby/Geometry)
  - `Sources/RubyfreeSystem/`(Capture: AXTextCapture/Fake/SecureField, Input: PollingMouseMonitor, Permissions: AXPermissionChecker)
- コマンド:
  - `swift build` / `swift run RubyfreeCoreTests`
  - `./Scripts/setup-dev-cert.sh`(初回) / `./Scripts/run-dev.sh`(実AX起動) / `RUBYFREE_FAKE_CAPTURE=1 swift run rubyfree`(Fake E2E)
  - `./Scripts/coverage.sh` / `./Scripts/audit-binary.sh rubyfree.app` / `./Scripts/pre-push.sh`
- Issues(open): #5(S0-5機内), #6(S0-6 AX実態), #9(M3 実AX残), #10(M4), #11(M5), #12(M6)。Milestones: S0/M1〜M6。
