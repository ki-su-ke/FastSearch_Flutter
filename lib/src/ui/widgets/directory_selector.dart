import 'package:flutter/material.dart';

/// ディレクトリ選択ウィジェット
/// ディレクトリ履歴からの選択とフォルダ選択ダイアログを提供する
class DirectorySelector extends StatelessWidget {
  /// 現在選択されているディレクトリ
  final String selectedDirectory;
  
  /// ディレクトリ履歴
  final List<String> directoryHistory;
  
  /// ディレクトリ選択時のコールバック
  final Function(String) onDirectorySelected;
  
  /// フォルダ選択ボタン押下時のコールバック
  final Future<void> Function() onBrowsePressed;

  /// コンストラクタ
  const DirectorySelector({
    super.key,
    required this.selectedDirectory,
    required this.directoryHistory,
    required this.onDirectorySelected,
    required this.onBrowsePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('検索対象ディレクトリ'),
            const SizedBox(height: 8),
            Row(
              children: [
                // ディレクトリ選択コンボボックス
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // initialValueを使用（非推奨のvalueの代わり）
                    initialValue: directoryHistory.contains(selectedDirectory) 
                            ? selectedDirectory 
                            : null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'ディレクトリを選択',
                    ),
                    items: directoryHistory
                        .map((dir) => DropdownMenuItem(
                              value: dir,
                              child: Text(
                                dir,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onDirectorySelected(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // ディレクトリ参照ボタン
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 124, 6, 69),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => onBrowsePressed(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('参照'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
