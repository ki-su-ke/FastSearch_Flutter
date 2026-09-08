import 'package:flutter/material.dart';
import '../../ffi/search_engine_wrapper.dart';

/// FILETIMEをDateTimeに変換するユーティリティ関数
/// Windows FILETIMEは1601年1月1日からの100ナノ秒単位
DateTime _fileTimeToDateTime(int fileTime) {
  // FILETIMEのエポック（1601年1月1日）
  final fileTimeEpoch = DateTime.utc(1601, 1, 1);
  // 100ナノ秒単位をマイクロ秒に変換（1マイクロ秒 = 1000ナノ秒）
  final microseconds = fileTime ~/ 10;
  return fileTimeEpoch.add(Duration(microseconds: microseconds));
}

/// 検索結果リストウィジェット
/// 検索結果を表示するリストを提供する
class SearchResultsList extends StatelessWidget {
  /// 検索結果のリスト
  final List<SearchResultItemData> searchResults;

  /// コンストラクタ
  const SearchResultsList({
    super.key,
    required this.searchResults,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: searchResults.isEmpty
          ? const Center(
              child: Text('検索結果がありません'),
            )
          : ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final item = searchResults[index];
                
                // FILETIMEをDateTimeに変換
                final lastWriteTime = _fileTimeToDateTime(item.lastWriteTime);
                final creationTime = _fileTimeToDateTime(item.creationTime);
                
                return ListTile(
                  title: Text(item.fileName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.filePath),
                      const SizedBox(height: 4),
                      Text(
                        '作成: ${creationTime.toLocal()}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        '更新: ${lastWriteTime.toLocal()}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${item.fileSize} bytes',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}
