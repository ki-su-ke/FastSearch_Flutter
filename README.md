# fast_search_flutter

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


----

## 下書き

### 概要

既存の FastSearchEngine (C++) のソースコードをできる限りそのまま活かしつつ、Flutter (Windowsデスクトップモード) から Dart FFI 経由で呼び出すという構成となっています。  

Flutterを使用するのははじめてなので、UIのFlutter部分はAIと壁打ちしつつ、ディレクトリ構成やアプリ構成から整理しながら進めていきました。  
これは当初から考えていたことですが、AIを使うことで未知の領域であっても飛び込みやすくなりますね。  
そして何より、こういうドキュメントをサクッと作ってくれるのは素晴らしいです。あーだこーだ壁打ちしながら進めていき、ポイントポイントで「ドキュメントに整理しておいて」っていうと追記してくれるなんて最高過ぎます。最高過ぎてディレクトリ構成とかファイル名とか実際のと異なってるかもしれません。その辺は見つけ次第修正していきます。  
自身の勉強もかねているのでエージェントモードは使っていませんが、それでも非常に助けになってます。  

少し話が逸れましたが、元々は既存のFastSearchEngineをFlutterから呼び出すという目的で始めたプロジェクトです。実際、ほとんどC++部分のコードには手をいれずに済みました。  
世の多くのDLLがこうやって整理されていないだろうとは思っていますが、DLLの境界を意識することで将来的にDLLを差し替えることも可能になるでしょう。  

今回はFlutterを使っていますが、UI部分を他の言語・技術に置き換えても問題無く対応できそうです。それが確認できたという点で個人的に価値のあるプロジェクトだったかなと思います。  

### 機能

シンプルなファイル検索アプリです。  
ただし、内部でWindowsのファイルシステムを直接扱っているため、他のプラットフォームでは動作しません。  

使い方は、  
1. 検索対象ディレクトリを選択する
2. 検索キーワードを入力する
3. 検索を実行する
とめっちゃシンプルです。  

内部的には、
1. 起動時にディレクトリ単位で(初期値Cドライブ)ファイルシステムを走査し、メモリ上でインデックスを構築します
2. 検索時には、メモリ上のインデックスから該当するファイルを高速に検索します
3. ドライブ変更が変更が伴う場合はUSNジャーナルの仕様上、再走査が必要になります

基本、MFC版と同じです。コア部分には全くというほど手を入れていません。  

### 構成

ディレクトリ構成図

FastSearch_with_Flutter/
├── android/                         <-- 各プラットフォーム用フォルダ
├── ios/
├── linux/
├── macos/
├── web/
├── windows/                        <-- Windows向けビルド設定
│   ├── CMakeLists.txt              <-- C++ビルド設定を追加する場所
│   └── ...
│
├── native/                         <-- 【C++領域】FastSearchEngine本体
│   ├── CMakeLists.txt              <-- nativeディレクトリ用ビルド設定
│   └── src/
│       ├── FastSearchEngine.h      <-- 既存ヘッダー（そのまま配置）
│       ├── FastSearchEngine.cpp    <-- 既存ソース（そのまま配置）
│       ├── SearchEngine_c_api.h    <-- 既存ヘッダー（MFC依存を排したからそのまま配置）
│       └── SearchEngine_c_api.cpp  <-- 既存ソース（MFC依存を排したからそのまま配置）
│
├── lib/                            <-- 【Dart/Flutter領域】アプリ UI & ロジック
│   ├── main.dart                   <-- アプリ起動エントリーポイント
│   ├── fast_search_engine_bindings.dart    <-- FFIバインディング定義(ffigenで生成)
│   └── src/
│       ├── ffi/
│       │   └── search_engine_wrapper.dart   <-- メモリ解放等のラップ処理
│       ├── services/
│       │   └── search_service.dart  <-- (新規作成) Isolateを使った非同期実行層
│       └── ui/
│           ├── widgets/
│           │   ├── directory_selector.dart  <-- ディレクトリ選択ウィジェット
│           │   ├── search_input.dart  <-- 検索入力ウィジェット
│           │   └── result_list.dart  <-- 検索結果リストウィジェット
│           |
│           └── search_page.dart     <-- 検索画面UI
│
├── pubspec.yaml                     <-- 依存パッケージ（ffi, ffigen等）管理
└── ffigen.yaml                      <-- (任意) Dartコード自動生成設定

#### この構成における設計上の利点

##### native_bindings.dart（自動生成コードの隔離）

ffigen で再生成された際も、ルート直下のこのファイルだけを上書きすればよく、import時にも迷わないで済みます。

##### search_bridge.dart（FFIの生の操作を隠蔽）

C++ 側の wchar_t* 変換や calloc.free、Engine_FreeSearchResults といったメモリ安全性の配慮をすべてこの中に閉じ込められます。  
Spring のDTOみたいな感じで。

##### search_service.dart（UIフリーズ防止）

C++ 側のインデックス検索がどれだけ高速でも、万単位のファイル走査を行うと Dart のメイン UI スレッド（Event Loop）を一瞬ブロックする可能性があります。ここで Isolate.run を使うことで、UI が完全に滑らかなまま検索を実行できます。

### 各レイヤーの役割とデータフロー

C++エンジンからFlutter UIまでのデータの流れと役割です。

Plaintext
[ C++ Engine ]            [ Bridge Layer ]             [ Dart / Flutter ]
+---------------------+   +---------------------+   +-----------------------+
| FastSearchEngine.cpp|   |   ffi_bridge.cpp    |   | native_bindings.dart  |
| (C++クラス/ロジック)| <->| (extern "C" Wrappers)| <->| (Dart FFI Functions)  |
+---------------------+   +---------------------+   +-----------------------+
                                                                |
                                                    +-----------------------+
                                                    |  search_service.dart  |
                                                    |  (Isolate / バックグラウンド)|
                                                    +-----------------------+
                                                                |
                                                    +-----------------------+
                                                    |    search_page.dart   |
                                                    |       (Flutter UI)    |
                                                    +-----------------------+

FastSearchEngine (C++): 既存のファイル検索・インデックス生成ロジック。

ffi_bridge.cpp: C++のクラスやメソッドを、Dart FFIから呼べる C言語形式の関数（extern "C"）としてラッパー公開するファイル。

windows/CMakeLists.txt: Flutterのビルドプロセスに native/ 配下のC++コードを組み込み、DLLとして出力させる設定ファイル。

native_bindings.dart: Dart側からDLLの関数ポインタをロード・定義する場所。

search_service.dart: FFI呼び出しを Isolate.run() でバックグラウンドスレッド化し、UIを止めずに検索を実行させるサービスクラス。

### 設計で気を付けた点
- Flutter側の構成を、Dart FFIで扱いやすいように橋渡しするwrapper層、UIとデータの中間で処理を行うサービス層、UI層にわけて責務を分離するようにした
- 今回はそれほど重要ではないのかもしれないが、UIウィジェットも責務分離の観点から分割しておくようにした
- Windows固有の機能を使うデスクトップアプリということで、他のプラットフォームの設定等はバッサリ切った
- Flutterでもローカルストレージ的なものがあるらしいということで、検索履歴などをそこで扱うようにした


### 苦労した点
- ffigenの設定
    - ffigenの記述方法に揺れがあるようで、正解にたどり着くまでに苦労した。将来も変わる可能性が高そう。
    - analysis_options.yaml内で呼んでいるformatterでエラーが発生して生成処理が進まないことが分かった。formatterなので、一時的に無効化して生成させる必要があった。
    - 純粋にC互換で定義しているなら、ffigenのcompile-optでは C言語用 を選ぶ方が素直に生成できる模様。
    - 今回はffigenを使うことにこだわった(AIが業界標準だというので)が、規模が小さいうちは自分で書いちゃう方が速いくらいだと思った。当のパートナーAIが音を上げたし。要はエラーメッセージを見て、clangが何を問題としていて、その結果何を取りこぼしてるのかを追跡していく作業が必要だった。

- デバッグ実行時のためのログ機能追加: エラーメッセージがすぐ消えてしまう・・・ということでlogger.dartを作成してエラー詳細をファイルに保存。
- Isolateエラー修正: DynamicLibraryがIsolate間で渡せない問題をFuture.microtask()で解決。これは盲点だった。

- UIの方に行くほどめっちゃコメント入れながら進めた。

### 今後の課題

これは実験プロジェクトですので、デスクトップアプリなら他にも選択肢があるわけです。  
ですから、今後これを大いに発展させていこうとは考えていませんが、Windows固有の機能を使っている以上マルチプラットフォームにはこのまま移行できません。  
どうせ移行するなら、もっとマルチプラットフォームに適した言語を使いたいよねって感じになると思うんで、同一のテーマで別のものをやろうかなとは考えています。自分用ツールとして。

----

## Flutter / FFIgen
コマンドメモ

```bash
dart run ffigen --config ffigen.yaml
```

----

## Build

```bash
flutter build windows
```

----

## Run

```bash
flutter run windows
```

----

## Debug

```bash
flutter run -d windows
```

----

## Release

```bash
flutter run windows --release
```

----

## Clean

```bash
flutter clean
```

----

## Dependencies

```bash
flutter pub get
```

----

## Pubspec

```bash
flutter pub upgrade
```

----

## Analyze

```bash
flutter analyze
```

----

## Test

```bash
flutter test
```

----



