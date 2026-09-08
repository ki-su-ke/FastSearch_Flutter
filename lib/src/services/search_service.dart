import '../ffi/search_engine_wrapper.dart';


//////////////////////////////////////////////////////
/// 検索サービスクラス
/// Isolateを使用してバックグラウンドで検索を実行し、UIフリーズを防止する
/// ※非同期処理をIsolate から Future へ変更。理由はDyanmic LibraryをIsolate間で渡せないため。
class SearchService {

  /// 検索エンジンのラッパーインスタンス
  late final SearchEngineWrapper _engine;

  /// サービスが初期化済みかどうかのフラグ
  bool _isInitialized = false;

  /// 現在インデックス化されているドライブ（例: "C:"）
  String? _currentDrive;

  /// コンストラクタ
  /// 検索エンジンを初期化する
  SearchService() {
    _initialize();
  }

  /// 検索エンジンを初期化するプライベートメソッド
  void _initialize() {
    try {
      _engine = SearchEngineWrapper();
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize SearchService: $e');
    }
  }

  /// パスからドライブ文字を抽出する（例: "C:\Users" -> "C:"）
  /// [path] フルパス
  /// 戻り値: ドライブ文字（例: "C:"）
  String _extractDriveLetter(String path) {
    if(path.isEmpty || path.length < 2) {
      return '';
    }
    // Windowsパス形式 "C:\..." からドライブ文字を抽出
    if (path[1] == ':') {
      return '${path[0]}:';
    }
    return '';
  }

  /// ドライブのインデックスを構築する（非同期）
  /// [driveLetter] ドライブ文字（例: "C:"）
  /// 戻り値: 成功した場合はtrue、失敗した場合はfalse
  Future<bool> buildIndexAsync(String driveLetter) async {
    if(!_isInitialized) {
      throw StateError('SearchService is not initilaized');
    }

    // Futureを使用して非同期実行（UIスレッドをブロックしない）
    // IsolateはDynamicLibraryを渡せないため使用しない
    // DynamicLibraryはネイティブリソースを保持しており、Isolate間でシリアライズできないため
    // 代わりにFuture.microtaskを使用してイベントループの次のティックで実行する
    final success = await Future.microtask(() => _engine.buildIndex(driveLetter));

    // 成功した場合、現在のドライブを更新
    if (success) {
      _currentDrive = driveLetter;
    }

    return success;
  }

  /// 指定されたパスのドライブがインデックス化されているか確認し、
  /// 必要であればインデックスを再構築する
  /// [path] 検索対象パス
  /// 戻り値: 成功した場合はtrue、失敗した場合はfalse
  Future<bool> ensureIndexForPathAsync(String path) async {
    final drive = _extractDriveLetter(path);
    if(drive.isEmpty) {
      return false;
    }

    // ドライブが変更された場合のみインデックス再構築
    if(_currentDrive != drive) {
      return await buildIndexAsync(drive);
    }

    return true; // すでにインデックス化されている
  }

  /// インデックス内のファイル数を取得する（非同期）
  /// 戻り値: ファイル数
  Future<int> getFileCountAsync() async {
    if(!_isInitialized) {
      throw StateError('SearchService is not initialized');
    }
    
    // Futureを使用して非同期実行（UIスレッドをブロックしない）
    // IsolateはDynamicLibraryを渡せないため使用しない
    return await Future.microtask(() => _engine.getFileCount());
  }

  /// ファイル検索を実行する（非同期）
  /// [keyword] 検索キーワード（ワイルドカード可能: *.txt, test* 等）
  /// [basePath] 検索対象のベースパス（例: "C:\\Users"）
  /// [maxResults] 最大結果数
  /// 戻り値: 検索結果のリスト
  Future<List<SearchResultItemData>> searchAsync(
    String keyword,
    String basePath,
    int maxResults
  ) async {
    if(!_isInitialized) {
      throw StateError('SearchService is not initialized');
    }

    // Futureを使用して非同期実行（UIスレッドをブロックしない）
    // IsolateはDynamicLibraryを渡せないため使用しない
    // 代わりにFuture.microtaskを使用してイベントループの次のティックで実行する
    return await Future.microtask(() => _engine.search(keyword, basePath, maxResults));
  }

  /// 現在インデックス化されているドライブを取得する
  /// 戻り値: ドライブ文字（例: "C:"）、インデックス化されていない場合はnull
  String? get currentDrive => _currentDrive;

  /// サービスを破棄し、リソースを解放する
  void dispose() {
    if(_isInitialized) {
      _engine.dispose();
      _isInitialized = false;
      _currentDrive = null;
    }
  }
}
