import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/search_service.dart';
import '../ffi/search_engine_wrapper.dart';

/// 検索ページのStatefulWidget
/// ファイル検索のUIとロジックを担当する
class SearchPage extends StatefulWidget {
  /// コンストラクタ
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

/// 検索ページのState
class _SearchPageState extends State<SearchPage> {
  // 検索サービスのインスタンス
  late final SearchService _searchService;
  
  // SharedPreferencesのインスタンス
  SharedPreferences? _prefs;
  
  // テキストフィールドのコントローラー
  final _keywordController = TextEditingController();
  final _maxResultsController = TextEditingController(text: '100');
  
  // ディレクトリ選択用
  String _selectedDirectory = '';
  List<String> _directoryHistory = [];
  
  // 検索結果のリスト
  List<SearchResultItemData> _searchResults = [];
  
  // ローディング状態
  bool _isLoading = false;
  bool _isInitializing = false;
  bool _isBuildingIndex = false;
  
  // ファイル数
  int _fileCount = 0;

  @override
  void initState() {
    super.initState();
    // 初期化処理を開始
    _initializeAsync();
  }

  /// 非同期初期化処理
  Future<void> _initializeAsync() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      // SharedPreferencesを初期化
      _prefs = await SharedPreferences.getInstance();
      
      // ディレクトリ履歴を読み込み
      _directoryHistory = _prefs?.getStringList('directory History') ?? [];
      
      // 履歴がある場合は最新のものを選択
      if (_directoryHistory.isNotEmpty) {
        _selectedDirectory = _directoryHistory.first;
      }
      
      // 検索サービスを初期化
      _searchService = SearchService();
      
      // Cドライブのインデックスを構築
      await _buildIndex('C:');
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初期化エラー: $e')),
        );
      }
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    // リソースを解放
    _searchService.dispose();
    _keywordController.dispose();
    _maxResultsController.dispose();
    super.dispose();
  }

  /// ディレクトリ履歴を保存する
  Future<void> _saveDirectoryHistory() async {
    if (_prefs == null) return;
    
    // 重複を削除して先頭に追加
    final updatedHistory = _directoryHistory
        .where((dir) => dir != _selectedDirectory)
        .toList();
    updatedHistory.insert(0, _selectedDirectory);
    
    // 最大10件に制限
    if (updatedHistory.length > 10) {
      updatedHistory.removeRange(10, updatedHistory.length);
    }
    
    _directoryHistory = updatedHistory;
    await _prefs!.setStringList('directoryHistory', _directoryHistory);
  }

  /// インデックスを構築するメソッド
  Future<void> _buildIndex(String driveLetter) async {
    setState(() {
      _isBuildingIndex = true;
    });

    try {
      // 指定されたドライブのインデックスを構築
      final success = await _searchService.buildIndexAsync(driveLetter);
      
      if (success) {
        // ファイル数を取得
        final count = await _searchService.getFileCountAsync();
        setState(() {
          _fileCount = count;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('インデックス構築完了: $count ファイル')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('インデックス構築に失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      setState(() {
        _isBuildingIndex = false;
      });
    }
  }

  /// フォルダ選択ダイアログを開く
  Future<void> _selectDirectory() async {
    try {
      // フォルダ選択ダイアログを表示
      final directory = await getDirectoryPath();
      
      if (directory != null) {
        setState(() {
          _selectedDirectory = directory;
        });
        
        // 履歴を保存
        await _saveDirectoryHistory();
        
        // ドライブが変更された場合、インデックスを再構築
        await _searchService.ensureIndexForPathAsync(directory);
        
        // ファイル数を更新
        final count = await _searchService.getFileCountAsync();
        setState(() {
          _fileCount = count;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('フォルダ選択エラー: $e')),
        );
      }
    }
  }

  /// 検索を実行するメソッド
  Future<void> _performSearch() async {
    final keyword = _keywordController.text.trim();
    final basePath = _selectedDirectory;
    final maxResults = int.tryParse(_maxResultsController.text) ?? 100;

    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('検索キーワードを入力してください')),
      );
      return;
    }

    if (basePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('検索対象ディレクトリを選択してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      // ドライブが変更された場合、インデックスを再構築
      await _searchService.ensureIndexForPathAsync(basePath);
      
      // 検索を実行
      final results = await _searchService.searchAsync(
        keyword,
        basePath,
        maxResults,
      );

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索エラー: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初期化中はローディング表示
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fast File Search'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body:	const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('検索エンジンを初期化中...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fast File Search'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // インデックス情報
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'インデックス: $_fileCount ファイル',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_isBuildingIndex)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // ディレクトリ選択エリア
            Card(
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
                            value: _selectedDirectory.isEmpty ? null : _selectedDirectory,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'ディレクトリを選択',
                            ),
                            items: _directoryHistory
                                .map((dir) => DropdownMenuItem(
                                      value: dir,
                                      child: Text(
                                        dir,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                setState(() {
                                  _selectedDirectory = value;
                                });
                                
                                // ドライブが変更された場合、インデックスを再構築
                                await _searchService.ensureIndexForPathAsync(value);
                                
                                // ファイル数を更新
                                final count = await _searchService.getFileCountAsync();
                                setState(() {
                                  _fileCount = count;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ディレクトリ参照ボタン
                        ElevatedButton.icon(
                          onPressed: _selectDirectory,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('参照'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 検索入力エリア
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _keywordController,
                      decoration: const InputDecoration(
                        labelText: '検索キーワード',
                        hintText: '*.txt, test* 等',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _maxResultsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '最大結果数',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 検索ボタン（大きめ）
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _performSearch,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text(
                                '検索',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 検索結果表示エリア
            Expanded(
              child: Card(
                child: _searchResults.isEmpty
                    ? const Center(
                        child: Text('検索結果がありません'),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            title: Text(item.fileName),
                            subtitle: Text(item.filePath),
                            trailing: Text(
                              '${item.fileSize} bytes',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
