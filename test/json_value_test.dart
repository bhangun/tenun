import 'package:flutter_test/flutter_test.dart';
import 'package:tenun_core/core/json_value.dart';

void main() {
  group('JsonValue cloning', () {
    test('deep-copies JSON-like maps and lists with string keys', () {
      final source = <Object?, Object?>{
        'items': [
          {
            'values': [1, 2],
          },
        ],
        12: 'numeric key',
      };

      final cloned = JsonValue.cloneMap(source);
      (((cloned['items'] as List).single as Map)['values'] as List).add(3);
      cloned['12'] = 'changed';

      expect((((source['items'] as List).single as Map)['values'] as List), [
        1,
        2,
      ]);
      expect(source[12], 'numeric key');
      expect(cloned.keys, contains('12'));
    });

    test('rejects cyclic maps and lists without overflowing the stack', () {
      final cyclicMap = <String, dynamic>{};
      cyclicMap['self'] = cyclicMap;

      final cyclicList = <dynamic>[];
      cyclicList.add(cyclicList);

      expect(
        () => JsonValue.cloneMap(cyclicMap),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => JsonValue.clone(cyclicList),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects over-nested maps and lists before stack overflow', () {
      expect(
        () => JsonValue.cloneMap(_nestedMap(JsonValue.maxTraversalDepth)),
        returnsNormally,
      );
      expect(
        () => JsonValue.clone(_nestedList(JsonValue.maxTraversalDepth)),
        returnsNormally,
      );
      expect(
        () => JsonValue.cloneMap(_nestedMap(JsonValue.maxTraversalDepth + 1)),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => JsonValue.clone(_nestedList(JsonValue.maxTraversalDepth + 1)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('JsonValue freezing', () {
    test('deep-freezes JSON-like maps and lists with string keys', () {
      final source = <Object?, Object?>{
        'items': [
          {
            'values': [1, 2],
          },
        ],
        12: 'numeric key',
      };

      final frozen = JsonValue.freezeMap(source);
      (((source['items'] as List).single as Map)['values'] as List).add(3);
      source[12] = 'changed source';

      expect(frozen.keys, contains('12'));
      expect(frozen['12'], 'numeric key');
      expect((((frozen['items'] as List).single as Map)['values'] as List), [
        1,
        2,
      ]);
      expect(() => frozen['12'] = 'changed', throwsA(isA<UnsupportedError>()));
      expect(
        () => (((frozen['items'] as List).single as Map)['late'] = true),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => (((frozen['items'] as List).single as Map)['values'] as List).add(
          4,
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects cyclic maps and lists without overflowing the stack', () {
      final cyclicMap = <String, dynamic>{};
      cyclicMap['self'] = cyclicMap;

      final cyclicList = <dynamic>[];
      cyclicList.add(cyclicList);

      expect(
        () => JsonValue.freezeMap(cyclicMap),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => JsonValue.freeze(cyclicList),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects over-nested maps and lists before stack overflow', () {
      expect(
        () => JsonValue.freezeMap(_nestedMap(JsonValue.maxTraversalDepth)),
        returnsNormally,
      );
      expect(
        () => JsonValue.freeze(_nestedList(JsonValue.maxTraversalDepth)),
        returnsNormally,
      );
      expect(
        () => JsonValue.freezeMap(_nestedMap(JsonValue.maxTraversalDepth + 1)),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => JsonValue.freeze(_nestedList(JsonValue.maxTraversalDepth + 1)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('JsonValue deep equality', () {
    test('compares nested JSON-like values structurally', () {
      final left = {
        'meta': {
          'tags': ['a', 'b'],
          'score': 4,
        },
        12: 'numeric key',
      };
      final right = {
        '12': 'numeric key',
        'meta': {
          'score': 4,
          'tags': ['a', 'b'],
        },
      };
      final changed = {
        '12': 'numeric key',
        'meta': {
          'score': 4,
          'tags': ['b', 'a'],
        },
      };

      expect(JsonValue.deepEquals(left, right), isTrue);
      expect(JsonValue.deepHash(left), JsonValue.deepHash(right));
      expect(JsonValue.deepEquals(left, changed), isFalse);
    });

    test('handles cyclic maps and lists without overflowing the stack', () {
      final leftMap = <String, dynamic>{'value': 1};
      leftMap['self'] = leftMap;
      final rightMap = <String, dynamic>{'value': 1};
      rightMap['self'] = rightMap;
      final changedMap = <String, dynamic>{'value': 2};
      changedMap['self'] = changedMap;

      expect(JsonValue.deepEquals(leftMap, rightMap), isTrue);
      expect(JsonValue.deepHash(leftMap), JsonValue.deepHash(rightMap));
      expect(JsonValue.deepEquals(leftMap, changedMap), isFalse);

      final leftList = <dynamic>[];
      leftList.add(leftList);
      final rightList = <dynamic>[];
      rightList.add(rightList);
      final changedList = <dynamic>[1];
      changedList.add(changedList);

      expect(JsonValue.deepEquals(leftList, rightList), isTrue);
      expect(JsonValue.deepHash(leftList), JsonValue.deepHash(rightList));
      expect(JsonValue.deepEquals(leftList, changedList), isFalse);
    });

    test(
      'handles over-nested maps and lists without overflowing the stack',
      () {
        final atLimitMap = _nestedMap(JsonValue.maxTraversalDepth);
        final atLimitList = _nestedList(JsonValue.maxTraversalDepth);
        final leftMap = _nestedMap(JsonValue.maxTraversalDepth + 1);
        final rightMap = _nestedMap(JsonValue.maxTraversalDepth + 1);
        final leftList = _nestedList(JsonValue.maxTraversalDepth + 1);
        final rightList = _nestedList(JsonValue.maxTraversalDepth + 1);

        expect(JsonValue.deepEquals(atLimitMap, atLimitMap), isTrue);
        expect(JsonValue.deepEquals(atLimitList, atLimitList), isTrue);
        expect(JsonValue.deepEquals(leftMap, rightMap), isFalse);
        expect(JsonValue.deepEquals(leftList, rightList), isFalse);
        expect(() => JsonValue.deepHash(leftMap), returnsNormally);
        expect(() => JsonValue.deepHash(leftList), returnsNormally);
      },
    );
  });

  group('JsonValue numeric parsing', () {
    test(
      'rejects non-finite doubles instead of leaking unsafe config values',
      () {
        expect(JsonValue.doubleOrNull(double.nan), isNull);
        expect(JsonValue.doubleOrNull(double.infinity), isNull);
        expect(JsonValue.doubleOrNull(double.negativeInfinity), isNull);
        expect(JsonValue.doubleOrNull('NaN'), isNull);
        expect(JsonValue.doubleOrNull('Infinity'), isNull);
        expect(JsonValue.doubleOrNull('-Infinity'), isNull);
      },
    );

    test('rejects non-finite ints without throwing', () {
      expect(JsonValue.intOrNull(double.nan), isNull);
      expect(JsonValue.intOrNull(double.infinity), isNull);
      expect(JsonValue.intOrNull(double.negativeInfinity), isNull);
    });

    test('accepts common grouped numeric strings', () {
      expect(JsonValue.doubleOrNull('1,234.5'), 1234.5);
      expect(JsonValue.doubleOrNull('1_234.5'), 1234.5);
      expect(JsonValue.doubleOrNull('-1,234e2'), -123400);
      expect(JsonValue.intOrNull('12,345'), 12345);
      expect(JsonValue.intOrNull('12_345'), 12345);
    });

    test('does not reinterpret malformed grouped numbers', () {
      expect(JsonValue.doubleOrNull('1,,234'), isNull);
      expect(JsonValue.doubleOrNull('1__234'), isNull);
      expect(JsonValue.intOrNull('1,234.5'), isNull);
    });
  });

  group('JsonValue typed collection parsing', () {
    test('extracts maps from mixed lists without throwing', () {
      expect(JsonValue.mapList('not-a-list'), isNull);
      expect(
        JsonValue.mapList([
          {'name': 'A'},
          'bad',
          {1: 'numeric key'},
        ]),
        [
          {'name': 'A'},
          {'1': 'numeric key'},
        ],
      );
    });

    test('parses int lists and matrices from stringly typed payloads', () {
      expect(JsonValue.intList('not-a-list'), isNull);
      expect(JsonValue.intList(['1', 2.7, double.nan, 'bad']), [1, 2]);
      expect(
        JsonValue.intMatrix([
          ['24', '3'],
          [4.0, 19],
          'bad-row',
          [double.infinity],
        ]),
        [
          [24, 3],
          [4, 19],
        ],
      );
    });
  });
}

Map<String, dynamic> _nestedMap(int depth) {
  Object? value = 'leaf';
  for (var i = 0; i < depth; i++) {
    value = <String, dynamic>{'child': value};
  }
  return value as Map<String, dynamic>;
}

List<dynamic> _nestedList(int depth) {
  Object? value = 'leaf';
  for (var i = 0; i < depth; i++) {
    value = <dynamic>[value];
  }
  return value as List<dynamic>;
}
