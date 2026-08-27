# めんどログ リリース手順（Runbook）

このドキュメントは、めんどログ（com.mendolog.mendolog）を Google Play に正式リリースするまでの手順です。
リポジトリ側の準備（identity・署名配線・アイコン・CI）は完了済みで、残りは鍵の生成と Play Console 操作です。

## 現状チェックリスト

- [x] applicationId / namespace = `com.mendolog.mendolog`
- [x] アプリ名（AndroidManifest label）= めんどログ
- [x] アイコン生成（Android 全密度 + adaptive + monochrome）
- [x] リリース署名配線（key.properties が無い場合は debug 署名にフォールバック）
- [x] CI（analyze / test / debug APK ビルド）
- [ ] Android リリースキー生成（下記）
- [ ] Google Play デベロッパーアカウントでアプリ作成
- [ ] Play App Signing 登録
- [ ] ストア掲載情報の記入
- [ ] AAB アップロード → 内部/クローズドテスト
- [ ] データセーフティ申告（ローカルのみ処理）

## 広告の本番引き継ぎ（Issue #36）

広告は無料コア体験を妨げない失敗安全なバナーとして実装しています。リポジトリには Google のテスト App ID / バナー広告ユニット ID のみを置いており、実広告 ID や秘密値はコミットしません。広告の読み込みに失敗しても、記録・履歴・集計・データ書き出しは利用できます。

本番化する際は、AdMob で Android/iOS のアプリと広告ユニットを作成し、`lib/ads.dart` と Android の manifest のテスト ID を安全なリリース設定へ差し替え、ストアの広告表示申告とプライバシー/同意要件を完了してから署名済みビルドで検証します。現在このリポジトリでは iOS プロジェクト、ストア設定、実機 runtime は未確認です。

## リリース前の環境要件（リリース実行マシン）

- Flutter SDK（README の `flutter analyze` / `flutter test` が通ること）
- Android toolchain: JDK 17、Android SDK
- `android/key.properties`（下記で生成）

## アップロードキー生成

```bash
cd android
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload -storepass "<PASS>" -keypass "<PASS>" \
  -dname "CN=mendolog, OU=Development, O=kaenozu, L=Tokyo, ST=Tokyo, C=JP"
```

- キーストアとパスワードはリポジトリ外（例: `~/mendolog-release-keys/`）に保管し、コミットしない。
- パスワードをチャットに貼らない。

`android/key.properties`（テンプレ: `android/key.properties.example`）を作成:

```properties
storeFile=../upload-keystore.jks
keyAlias=upload
storePassword=<PASS>
keyPassword=<PASS>
```

## 署名付き AAB のビルドと検証

```bash
flutter build appbundle --release
jarsigner -verify -verbose -certs app-release.aab 2>&1 | grep -i "upload\|debug" | head
```

- 署名者が `CN=Android Debug` ではなく `CN=mendolog`（アップロードキー）であることを確認する。

## マニフェスト権限の監査

```bash
grep -E "uses-permission" android/app/src/main/AndroidManifest.xml
```

- アプリは端末内完結（SharedPreferences に JSON 保存・ネットワークなし）のため、
  `INTERNET` / `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` が無いことを確認する。

## Play Console 手順

1. Play Console でデベロッパーアカウントにログイン → アプリ作成（applicationId: `com.mendolog.mendolog`）
2. Play App Signing を登録（アップロードキー: 上で生成したもの）
3. ストア掲載情報:
   - 名前: めんどログ
   - 短い説明（80文字以内）: 日常の小さな摩擦を3秒で記録。繰り返す不便を自動で見つけるログアプリ
   - 長い説明: MVP 機能・ローカル完結（データは端末内のみ・ネットワーク送信なし）を記載
4. AAB をアップロード → 内部テスト → クローズドテスト（テスター招待）
5. データセーフティ: ローカルのみで処理（共有なし）を申告。ターゲットユーザーを先に申告してからデータセーフティを保存する

## 定義: リリース可能の判定

上記チェックリストの未チェック項目（鍵生成・Play 登録・ストア情報・テスト公開）が全て完了し、
クローズドテストで実機動作確認が取れた時点でリリース可能とする。