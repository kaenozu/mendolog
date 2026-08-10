# めんどログ

日常の小さな摩擦を3秒で記録し、繰り返す不便を見つけて改善するローカル完結のFlutter Android MVPです。

## MVP

- 「探した」「忘れた」「やり直した」「待った」「面倒だった」「その他」の高速入力
- 最近使った対象の再利用
- 同一カテゴリ × 同一対象の直近30日集計
- 3回以上で改善候補を表示
- 「探した」×「爪切り」には「定位置を決める」を提案
- 改善開始日を保存し、改善前後30日の発生回数を比較
- 表記揺れ（つめきり / 爪きり / ネイルクリッパー）を「爪切り」に集約
- データは端末内のSharedPreferencesへJSONで保存（ネットワーク・AIなし）

## 確認方法

```text
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

`integration_test/` に実機フローを用意しています。実機またはAndroidエミュレーター未接続の環境では、integration_testの実行結果は未確認です。

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
