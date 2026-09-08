import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/search_service.dart';
import '../ffi/search_engine_wrapper.dart';
import '../utils/logger.dart';
import 'widgets/directory_selector.dart';
import 'widgets/search_input.dart';
import 'widgets/search_results_list.dart';

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
    Logger.instance.dispose();
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
      // Windowsでは初期ディレクトリを指定する必要がある場合がある
      
      // 初期ディレクトリとして現在選択されているディレクトリを使用
      final initialDirectory = _selectedDirectory.isNotEmpty 
          ? _selectedDirectory 
          : null;
      
      Logger.instance.info('フォルダ選択ダイアログを開きます: initialDirectory=$initialDirectory');
      
      final directory = await getDirectoryPath(
        initialDirectory: initialDirectory,
      );
      
      if (directory != null) {
        Logger.instance.info('フォルダが選択されました: $directory');
        
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
      } else {
        Logger.instance.info('フォルダ選択がキャンセルされました');
      }
    } catch (e, stackTrace) {
      Logger.instance.error(
        'フォルダ選択エラー',
        error: e,
        stackTrace: stackTrace,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('フォルダ選択エラー: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
        // デバッグ用にスタックトレースも出力
        debugPrint('フォルダ選択エラー: $e');
        debugPrint('スタックトレース: $stackTrace');
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
          // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
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
        // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
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
            
            // ディレクトリ選択エリア（ウィジェット化）
            DirectorySelector(
              selectedDirectory: _selectedDirectory,
              directoryHistory: _directoryHistory,
              onDirectorySelected: (directory) async {
                setState(() {
                  _selectedDirectory = directory;
                });
                
                // ドライブが変更された場合、インデックスを再構築
                await _searchService.ensureIndexForPathAsync(directory);
                
                // ファイル数を更新
                final count = await _searchService.getFileCountAsync();
                setState(() {
                  _fileCount = count;
                });
              },
              onBrowsePressed: _selectDirectory,
            ),
            const SizedBox(height: 16),
            
            // 検索入力エリア（ウィジェット化）
            SearchInput(
              keywordController: _keywordController,
              maxResultsController: _maxResultsController,
              isLoading: _isLoading,
              onSearchPressed: _performSearch,
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16),
            
            // 検索結果表示エリア（ウィジェット化）
            Expanded(
              child: SearchResultsList(
                searchResults: _searchResults,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
