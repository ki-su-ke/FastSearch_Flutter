import 'package:flutter/material.dart';


/// 検索入力ウィジェット
/// 検索キーワード、最大結果数の入力と検索ボタンを提供する
class SearchInput extends StatelessWidget {
  /// 検索キーワードのコントローラー
  final TextEditingController keywordController;

  /// 最大結果数のコントローラー
  final TextEditingController maxResultsController;

  /// 検索実行中かどうか
  final bool isLoading;

  /// 検索実行時のコールバック
  final VoidCallback onSearchPressed;

  /// エンターキー押下時のコールバック
  final Function(String) onSubmitted;

  /// コンストラクタ
  const SearchInput({
    super.key,
    required this.keywordController,
    required this.maxResultsController,
    required this.isLoading,
    required this.onSearchPressed,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 検索キーワード（5割）
            Expanded(
              flex: 5,
              child: TextField(
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '検索キーワード',
                  hintText: '*.txt, test* 等',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: onSubmitted,
              ),
            ),
            const SizedBox(width: 8),
            // 最大結果数（1割）
            Expanded(
              flex: 1,
              child: TextField(
                controller: maxResultsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '最大結果数',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 検索ボタン（4割）
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 56,
                // child: ElevatedButton(
                //   onPressed: isLoading ? null : onSearchPressed,
                //   child: isLoading
                //       ? const CircularProgressIndicator()
                //       : const Text(
                //           '検索',
                //           style: TextStyle(fontSize: 18),
                //         ),
                // ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 124, 6, 69),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: isLoading ? null : onSearchPressed,
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('検索',),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
