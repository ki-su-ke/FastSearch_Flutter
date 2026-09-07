import 'dart:io';

/// ログユーティリティクラス
/// エラー情報をファイルに保存する
class Logger {
  static Logger? _instance;
  
  /// ログファイルのパス
  late final String _logFilePath;
  
  /// ログファイルへの書き込みストリーム
  IOSink? _logSink;
  
  /// シングルトンパターン
  static Logger get instance {
    _instance ??= Logger._internal();
    return _instance!;
  }
  
  /// プライベートコンストラクタ
  Logger._internal() {
    // ログファイルのパスを設定（実行ディレクトリ）
    final currentDir = Directory.current.path;
    _logFilePath = '$currentDir\\app_log.txt';
    
    // 既存のログファイルがあれば削除（起動時にクリア）
    final logFile = File(_logFilePath);
    if (logFile.existsSync()) {
      logFile.deleteSync();
    }
    
    // ログファイルを作成して書き込みストリームを開く
    _logSink = logFile.openWrite(mode: FileMode.append);
  }
  
  /// エラーログを書き込む
  /// [message] エラーメッセージ
  /// [error] エラーオブジェクト
  /// [stackTrace] スタックトレース
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer();
    
    buffer.writeln('[$timestamp] ERROR: $message');
    if (error != null) {
      buffer.writeln('Error: $error');
    }
    if (stackTrace != null) {
      buffer.writeln('Stack Trace:');
      buffer.writeln(stackTrace.toString());
    }
    buffer.writeln('---');
    
    _logSink?.write(buffer.toString());
    _logSink?.flush();
    
    // コンソールにも出力
    print(buffer.toString());
  }
  
  /// 情報ログを書き込む
  /// [message] メッセージ
  void info(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] INFO: $message\n';
    
    _logSink?.write(logLine);
    _logSink?.flush();
    
    // コンソールにも出力
    print(logLine);
  }
  
  /// リソースを解放する
  void dispose() {
    _logSink?.close();
  }
}
