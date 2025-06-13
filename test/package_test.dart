import 'dart:convert';
import 'dart:io';

import 'package:sheets_store/sheets_store.dart';
import 'package:test/test.dart';

Map<String, dynamic> readJsonFile(String filePath) {
  final input = File(filePath).readAsStringSync();
  final decoded = jsonDecode(input);
  return decoded;
}

void main() async {
  final client = await SheetsClient.fromServiceAccountCredentials(
    readJsonFile('./secrets/secrets.json')['testSpreadsheetId'],
    readJsonFile('./secrets/credentials.json'),
  );
  final sheetColumn = SheetColumn<String>(
    sheetsClient: client,
    column: 'A',
    sheetName: 'Test Sheet',
  );

  test('Test SheetColumn', () async {
    expect(await sheetColumn.at(0), 'Entry1');

    expect(
      await sheetColumn.find((value, index) => value == 'Entry99'),
      'Entry99',
    );

    expect(await sheetColumn.length, 5);

    final randomNumber = DateTime.now().second;
    expect(await sheetColumn.set(2, 'Test Entry$randomNumber'), true);

    expect(await sheetColumn.delete(5), true);

    expect(await sheetColumn.bulkRead(0, 1), ['Entry1', 'Entry99']);

    final randomNum2 = DateTime.now().second;
    expect(
      await sheetColumn.bulkSet(3, [
        'Entry$randomNum2',
        'Entry${randomNum2 + 1}',
      ]),
      true,
    );
  });

  test('Test SheetMap', () async {
    final map = SheetMap<String, num>(
      client: client,
      sheetName: 'Test Sheet',
      keyColumn: 'C',
      valueColumn: 'D',
    );

    await map.set('one', 1);
    await map.set('two', 2);
    await map.set('three', 3);
    await map.set('four', 4);

    expect(await map.get('one'), 1);
    expect(await map.get('two'), 2);
    expect(await map.get('three'), 3);
    expect(await map.get('four'), 4);

    expect(await map.has('one'), true);
    expect(await map.has('random'), false);

    expect(await map.allKeys(), ['one', 'two', 'three', 'four']);
    expect(await map.allValues(), [1, 2, 3, 4]);

    expect(await map.delete('four'), true);
    expect(await map.delete('random'), false);
  });

  test('Test SheetTable', () async {
    final table = SheetTable(
      client: client,
      sheetName: 'Table',
    );

    await table.clear();

    final dummyData = {
      "a": 1,
      "b": 2,
      "c": 3,
      "d": 4,
      "e": 5,
    };

    expect(await table.append(dummyData), 2); // Write test

    final dummyKey = {"1": 2, "4": true, "6": 4};
    final dummyEntry = {"1": 2, "9": true, "3": 4};
    // complex type write test
    expect(await table.append({dummyKey: dummyEntry}), 3);
    expect(await table.append({'futureTest': 69}), 4);

    expect(await table.at(2), dummyData); // Read test

    // set/update test
    expect(await table.update(4, dummyData), true);
    // verify write test
    expect(await table.at(4), {
      "a": 1,
      "b": 2,
      "c": 3,
      "d": 4,
      "e": 5,
      'futureTest': 69,
    });

    expect(await table.appendAtKey("b", [5, 6, 7, 26, 24]), true);
    // include writes from above
    expect(await table.valuesOfKey("b"), [2, 2, 5, 6, 7, 26, 24]);

    expect(await table.pick('a', 2), 1);

    expect(await table.append({'nullValue': null}), 10);
    expect(await table.at(10), {'nullValue': null});

    expect(await table.valuesOfKeys(['a', 'b', 'futureTest', 'nullValue']), {
      'a': [1, 1],
      'b': [2, 2, 5, 6, 7, 26, 24],
      'futureTest': [69],
      'nullValue': [null],
    });

    expect(await table.deleteKey('futureTest'), true);
    expect(await table.hasKey('futureTest'), false);

    predicate(key) => key.runtimeType == String;

    expect(await table.findKey(predicate), 'a');

    expect(await table.findKeys(predicate), [
      'a',
      'b',
      'c',
      'd',
      'e',
      'nullValue',
    ]);

    final searchingFor = {
      'a': 1,
      'b': 2,
      'c': 3,
      'd': 4,
      'e': 5,
    };
    expect(
      await table.findEntry(
        (entry, index) =>
            entry.toString() == searchingFor.toString() && index > 2,
      ),
      searchingFor,
    );
  });
}
