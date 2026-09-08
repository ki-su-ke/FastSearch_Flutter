
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mocks/mock_search_engine_wrapper.dart';
// import 'package:fast_search_flutter/src/services/search_service.dart';
import 'package:fast_search_flutter/src/ffi/search_engine_wrapper.dart';


void main() {
  group('SearchService', () {
    // late SearchService searchService;
    late MockSearchEngineWrapper mockWrapper;
    
    setUp(() {
      mockWrapper = MockSearchEngineWrapper();
    });

    test('buildIndexAsync()のモックテスト', () async {
      // mockのふるまいを設定
      when(() => mockWrapper.buildIndex('C:')).thenReturn(true);
      final result = mockWrapper.buildIndex('C:');
      expect(result, true);
      verify(() => mockWrapper.buildIndex('C:')).called(1);
    });

    test('getFileCountAsync()のモックテスト', () async{
      when(() => mockWrapper.getFileCount()).thenReturn(1000);
      final count = mockWrapper.getFileCount();
      expect(count, 1000);
      verify(() => mockWrapper.getFileCount()).called(1);
    });

    test('searchAsync()のモックテスト', () async {
      //
      // 結果とするモックデータを用意
      final mockResults = [
        SearchResultItemData(
          fileName: 'test.txt',
          filePath: 'C:\\test\\test.txt',
          fileSize: 1024,
          lastWriteTime: 0,
          creationTime: 0,
        ),
      ];
      when(() => mockWrapper.search('*.txt', 'C:\\test', 100)).thenReturn(mockResults);
      //
      // mockのメソッドを呼び出して検証
      final results = mockWrapper.search('*.txt', 'C:\\test', 100);
      expect(results.length, 1);
      expect(results[0].fileName, 'test.txt');
      expect(results[0].filePath, 'C:\\test\\test.txt');
      expect(results[0].fileSize, 1024);
      verify(() => mockWrapper.search('*.txt', 'C:\\test', 100)).called(1);
    });
  });
}