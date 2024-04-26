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
    decodeFunction: (json) => jsonDecode(json),
  );

  test('Test SheetColumn.at functionality', () async {
    expect(await sheetColumn.at(0), 'Entry1');
  });

  test('Test SheetColumn.find functionality', () async {
    expect(
      await sheetColumn.find((value, index) => value == 'Entry99'),
      'Entry99',
    );
  });

  test('Test SheetColumn.getEntries functionality', () async {
    final entries = await sheetColumn.getEntries();
    expect(entries.length, 6);
  });

  test('Test SheetColumn.set functionality', () async {
    final randomNumber = DateTime.now().second;
    expect(await sheetColumn.set(2, 'Test Entry$randomNumber'), true);
  });

  test('Test SheetColumn.delete functionality', () async {
    expect(await sheetColumn.delete(5), true);
  });

  test('Test SheetColumn.bulkRead functionality', () async {
    expect(await sheetColumn.bulkRead(0, 1), ['Entry1', 'Entry99']);
  });

  test('Test SheetColumn.bulkSet functionality', () async {
    final randomNumber = DateTime.now().second;
    expect(
      await sheetColumn.bulkSet(3, [
        'Entry$randomNumber',
        'Entry${randomNumber + 1}',
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
      decodeFunction: (raw) => jsonDecode(raw),
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
}
