import 'dart:convert';
import 'dart:io';

import 'package:sheets_store/sheets_store.dart';

Map<String, dynamic> readJsonFile(String filePath) {
  final input = File(filePath).readAsStringSync();
  final decoded = jsonDecode(input);
  return decoded;
}

void main() async {
  final client = await SheetsClient.fromServiceAccountCredentials(
    'ENTER YOUR SPREADSHEET ID HERE',
    readJsonFile('ENTER YOUR JSON CREDENTIALS FILE HERE'),
  );
  final testTable = SheetColumn<String>(
    column: 'A',
    sheetName: 'Sheet1',
    sheetsClient: client,
    decodeFunction: (rawValue) => jsonDecode(rawValue),
  );

  // Print an element in the table
  final firstRowElement = await testTable.at(0);
  print(firstRowElement);

  // Write to the table
  testTable.set(1, 'Hello World');
}
