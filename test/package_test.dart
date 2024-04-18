import 'dart:convert';
import 'dart:io';

import 'package:sheets_database/sheets_database.dart';
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
  final table =
      Table<String>(sheetsClient: client, column: 'A', sheetName: 'Users');

  test('Test Table.at functionality', () async {
    expect(await table.at(0), 'Entry1');
  });

  test('Test Table.find functionality', () async {
    expect(await table.find((value, index) => value == 'Entry99'), 'Entry99');
  });

  test('Test Table.getEntries functionality', () async {
    final entries = await table.getEntries();
    expect(entries.length, 100);
  });

  test('Test Table.set functionality', () async {
    final randomNumber = DateTime.now().second;
    expect(await table.set(5, 'Test Entry$randomNumber'), true);
  });

  test('Test Table.bulkRead functionality', () async {
    expect(await table.bulkRead(0, 2), ['Entry1', 'Entry2']);
  });

  test('Test Table.bulkSet functionality', () async {
    final randomNumber = DateTime.now().second;
    expect(
      await table.bulkSet(9, [
        'Entry$randomNumber',
        'Entry${randomNumber + 1}',
      ]),
      true,
    );
  });
}
