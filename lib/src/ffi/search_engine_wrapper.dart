import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:fast_search_flutter/fast_search_engine_bindings.dart';


//////////////////////////////////////////////////
/// 検索結果1項目を表すDartデータクラス
/// C++のSearchResultItem構造体に対応
class SearchResultItemData {

  /// ファイル名（フルパスではない）
  final String fileName;

  /// ファイルのフルパス
  final String filePath;

  /// ファイルサイズ(バイト)
  final int fileSize;

  /// 最終更新日時（FILETIME形式のunsigned long long）
  final int lastWriteTime;
  
  /// 作成日時（FILETIME形式のunsigned long long）
  final int creationTime;

  SearchResultItemData({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.lastWriteTime,
    required this.creationTime,
  });
}

//////////////////////////////////////////////////////////
/// FastSearchEngineのFFIラッパークラス
/// C++ DLLの生のFFI呼び出しを隠蔽し、メモリ管理と文字列変換を担当する
class SearchEngineWrapper {

  /// FFIバインディングのインスタンス
  late final FastSearchEngineBindings _bindings;

  /// エンジンハンドル（C++側のインスタンスポインタ）
  late final SearchEngineHandle _handle;

  /// DLLがロード済みかどうかの内部フラグ
  bool _isInitialized = false;
  
  /// コンストラクタ
  /// DLLをロードし、エンジンインスタンスを作成する
  SearchEngineWrapper() {
    // 
    // Platform Windowsかどうかを確認
    if(!Platform.isWindows) {
      throw UnsupportedError('This library only supports Windows');
    }
    //
    // 初期化
    _initialized();
  }

  /// DLLのロードとエンジン初期化を行うプライベートメソッド
  void _initialized() {
    try {
      // Windows環境でDLLをロード（相対パスで検索）
      // Flutterのビルド設定でDLLが実行ファイルと同じ場所にコピーされる
      final dyLib = DynamicLibrary.open('FileSearchEngine.dll');
      //
      // FFIバインディングを初期化
      _bindings = FastSearchEngineBindings(dyLib);
      //
      // C++側のエンジンインスタンスを作成
      _handle = _bindings.Engine_Create();

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize SearchEngine: $e');
    }
  }

  /// ドライブのインデックスを構築する
  /// [driveLetter] ドライブ文字（例: "C:"）
  /// 戻り値: 成功した場合はtrue、失敗した場合はfalse
  bool buildIndex(String driveLetter) {
    if(!_isInitialized) {
      throw StateError('SearchEngine is not initialized');
    }
    //
    // DartのStringをwchar_t*に変換（Utf16として）
    // Arenaを使用して自動メモリ管理を行う
    // Arena(Arena Allocator)は、「そのエリア内で確保したメモリを、最後にまとめて一括で解放する」ためのもの
    final arena = Arena();
    try {
      final drivePtr = driveLetter.toNativeUtf16(allocator: arena);
      //
      // Utf16ポインタをWCharポインタにキャスト
      final wCharPtr = drivePtr.cast<WChar>();
      //
      // C++側のBuildIndex関数を呼び出し
      final result = _bindings.Engine_BuildIndex(_handle, wCharPtr);
      return result == 1; // 1 = 成功, 0 = 失敗
    } finally {
      arena.releaseAll();
    }
  }

  /// インデックス内のファイル数を取得する
  /// 戻り値: ファイル数
  int getFileCount() {
    if(!_isInitialized) {
      throw StateError('SearchEngine is not initialized');
    }
    
    return _bindings.Engine_GetFileCount(_handle);
  }

  /// ファイル検索を実行する
  /// [keyword] 検索キーワード（ワイルドカード可能: *.txt, test* 等）
  /// [basePath] 検索対象のベースパス（例: "C:\\Users"）
  /// [maxResults] 最大結果数
  /// 戻り値: 検索結果のリスト
  List<SearchResultItemData> search(
    String keyword,
    String basePath,
    int maxResults,
  ) {
    if(!_isInitialized) {
      throw StateError('SearchEngine is not initialized');
    }

    // ここでもArenaを使用して自動メモリ管理を行う
    final arena = Arena();
    try {
      //
      // DartのStringをwchar_t*に変換（Utf16として）
      final keywordPtr = keyword.toNativeUtf16(allocator: arena);
      final basePathPtr = basePath.toNativeUtf16(allocator: arena);
      //
      // Utf16ポインタをWCharポインタにキャスト
      final keywordWCharPtr = keywordPtr.cast<WChar>();
      final basePathWCharPtr = basePathPtr.cast<WChar>();

      // C++側のSearch関数を呼び出し
      final results = _bindings.Engine_Search(
                                  _handle,
                                  keywordWCharPtr,
                                  basePathWCharPtr,
                                  maxResults);
      // 結果をDartのリストに変換
      final resultList = <SearchResultItemData>[];
      //
      // 結果配列を走査
      for(var i = 0; i < results.count; i++) {
        final item = results.items[i];
        //
        // WCharポインタをUtf16ポインタとしてキャストし、DartのStringに変換
        final fileNamePtr = item.fileName.cast<Utf16>();
        final filePathPtr = item.filePath.cast<Utf16>();
        final fileName = fileNamePtr.toDartString();
        final filePath = filePathPtr.toDartString();
        //
        // Dartのデータクラスに変換して追加
        resultList.add(SearchResultItemData(
          fileName: fileName,
          filePath: filePath,
          fileSize: item.fileSize,
          lastWriteTime: item.lastWriteTime,
          creationTime: item.creationTime,
        ));
      }

      // C++側のメモリを解放（ポインタを渡す）
      final resultsPtr = arena<SearchResults>();
      resultsPtr.ref = results;
      _bindings.Engine_FreeSearchResults(resultsPtr);

      return resultList;
    } finally {
      arena.releaseAll();
    }
  }

  /// エンジンインスタンスを破棄し、リソースを解放する
  void dispose() {
    if(_isInitialized) {
      _bindings.Engine_Destroy(_handle);
      _isInitialized = false;
    }
  }
}

/* 元のソース
/// FastSearchEngineのFFIラッパークラス
/// C++ DLLの生のFFI呼び出しを隠蔽し、メモリ管理と文字列変換を担当する
class SearchEngineWrapper {
  /// FFIバインディングのインスタンス
  late final FastSearchEngineBindings _bindings;
  
  // エンジンハンドル（C++側のインスタンスポインタ）
  late final SearchEngineHandle _handle;
  
  // DLLがロード済みかどうかのフラグ
  bool _isInitialized = false;

  /// コンストラクタ
  /// DLLをロードし、エンジンインスタンスを作成する
  SearchEngineWrapper() {
    //
    // Platform Windowsかどうかを確認
    if(!Platform.isWindows) {
      throw UnsupportedError('This library only supports Windows');
    }
    //
    // 初期化
    _initialize();
  }

  /// DLLのロードとエンジン初期化を行うプライベートメソッド
  void _initialize() {
    try {
      // Windows環境でDLLをロード（相対パスで検索）
      // Flutterのビルド設定でDLLが実行ファイルと同じ場所にコピーされる
      final dylib = DynamicLibrary.open('FileSearchEngine.dll');
      
      // FFIバインディングを初期化
      _bindings = FastSearchEngineBindings(dylib);
      
      // C++側のエンジンインスタンスを作成
      _handle = _bindings.Engine_Create();
      
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize SearchEngine: $e');
    }
  }

  /// ドライブのインデックスを構築する
  /// [driveLetter] ドライブ文字（例: "C:"）
  /// 戻り値: 成功した場合はtrue、失敗した場合はfalse
  bool buildIndex(String driveLetter) {
    if (!_isInitialized) {
      throw StateError('SearchEngine is not initialized');
    }

    // DartのStringをwchar_t*に変換（Utf16として）
    // Arenaを使用して自動メモリ管理を行う
    final arena = Arena();
    try {
      final drivePtr = driveLetter.toNativeUtf16(allocator: arena);
      // Utf16ポインタをWCharポインタにキャスト
      final wCharPtr = drivePtr.cast<WChar>();
      
      // C++側のBuildIndex関数を呼び出し
      final result = _bindings.Engine_BuildIndex(_handle, wCharPtr);
      return result == 1; // 1 = 成功, 0 = 失敗
    } finally {
      // Arenaが自動的にメモリを解放
      arena.releaseAll();
    }
  }

  /// インデックス内のファイル数を取得する
  /// 戻り値: ファイル数
  int getFileCount() {
    if (!_isInitialized) {
      throw StateError('SearchEngine is not initialized');
    }
    
    return _bindings.Engine_GetFileCount(_handle);
  }

  /// ファイル検索を実行する
  /// [keyword] 検索キーワード（ワイルドカード可能: *.txt, test* 等）
  /// [basePath] 検索対象のベースパス（例: "C:\\Users"）
  /// [maxResults] 最大結果数
  /// 戻り値: 検索結果のリスト
  List<SearchResultItemData> search(
    String keyword,
    String basePath,
    int maxResults,
  ) {
    if (!_isInitialized) {
      throw StateError('SearchEngine is not initialized');
    }

    // Arenaを使用して自動メモリ管理を行う
    final arena = Arena();
    try {
      // DartのStringをwchar_t*に変換（Utf16として）
      final keywordPtr = keyword.toNativeUtf16(allocator: arena);
      final basePathPtr = basePath.toNativeUtf16(allocator: arena);
      
      // Utf16ポインタをWCharポインタにキャスト
      final keywordWCharPtr = keywordPtr.cast<WChar>();
      final basePathWCharPtr = basePathPtr.cast<WChar>();
      
      // C++側のSearch関数を呼び出し
      final results = _bindings.Engine_Search(
        _handle,
        keywordWCharPtr,
        basePathWCharPtr,
        maxResults,
      );
      
      // 結果をDartのリストに変換
      final resultList = <SearchResultItemData>[];
      
      // 結果配列を走査
      for (var i = 0; i < results.count; i++) {
        // i番目のアイテムを取得
        final item = results.items[i];
        
        // WCharポインタをUtf16ポインタとしてキャストし、DartのStringに変換
        final fileNamePtr = item.fileName.cast<Utf16>();
        final filePathPtr = item.filePath.cast<Utf16>();
        final fileName = fileNamePtr.toDartString();
        final filePath = filePathPtr.toDartString();
        
        // Dartのデータクラスに変換して追加
        resultList.add(SearchResultItemData(
          fileName: fileName,
          filePath: filePath,
          fileSize: item.fileSize,
          lastWriteTime: item.lastWriteTime,
          creationTime: item.creationTime,
        ));
      }
      
      // C++側のメモリを解放（ポインタを渡す）
      final resultsPtr = arena<SearchResults>();
      resultsPtr.ref = results;
      _bindings.Engine_FreeSearchResults(resultsPtr);
      
      return resultList;
    } finally {
      // Arenaが自動的にメモリを解放
      arena.releaseAll();
    }
  }

  /// エンジンインスタンスを破棄し、リソースを解放する
  void dispose() {
    if (_isInitialized) {
      _bindings.Engine_Destroy(_handle);
      _isInitialized = false;
    }
  }
}

/// 検索結果1項目を表すDartデータクラス
/// C++のSearchResultItem構造体に対応
class SearchResultItemData {
  /// ファイル名のみ（フルパスではない）
  final String fileName;
  
  /// ファイルのフルパス
  final String filePath;
  
  /// ファイルサイズ（バイト）
  final int fileSize;
  
  /// 最終更新日時（FILETIME形式のunsigned long long）
  final int lastWriteTime;
  
  /// 作成日時（FILETIME形式のunsigned long long）
  final int creationTime;

  SearchResultItemData({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.lastWriteTime,
    required this.creationTime,
  });
}
*/
