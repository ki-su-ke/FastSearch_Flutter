import 'package:flutter/material.dart';
// 新しい検索ページをインポート
import 'src/ui/search_page.dart';

/// アプリケーションのエントリーポイント
void main() {
  runApp(const MyApp());
}

/// アプリケーションのルートウィジェット
class MyApp extends StatelessWidget {
  /// コンストラクタ
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fast File Search',
      theme: ThemeData(
        // アプリケーションのテーマ設定
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // 検索ページをホーム画面として設定
      home: const SearchPage(),
    );
  }
}
