import 'dart:async';
import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/sheets/v4.dart';

class SheetsClient {
  SheetsClient({
    required AuthClient authenticatedClient,
    required String targetSpreadsheetId,
  }) {
    sheets = SheetsApi(authenticatedClient);
    ssId = targetSpreadsheetId;
  }

  /// Google Sheets API Client
  late SheetsApi sheets;

  /// The spreadsheet the database is stored on
  late String ssId;

  /// Use Service Credentials to get authenticated
  static Future<SheetsClient> fromServiceAccountCredentials(
      String targetSpreadsheetId, Object? jsonCredentials) async {
    final accountCredentials = ServiceAccountCredentials.fromJson(
      jsonCredentials,
    );
    const scopes = ["https://www.googleapis.com/auth/spreadsheets"];
    final c = await clientViaServiceAccount(accountCredentials, scopes);
    return SheetsClient(
      authenticatedClient: c,
      targetSpreadsheetId: targetSpreadsheetId,
    );
  }
}

/// A table to store data in represented as a column in sheets
class Table<T> {
  Table({
    required this.sheetsClient,
    required this.column,
    required this.sheetName,
  });

  final SheetsClient sheetsClient;
  final String column;
  final String sheetName;

  /// Retrieves the item at the specified index (Row).
  /// Index starts at 0
  Future<T> at(int index) async {
    final res = await readRange('$column${index + 1}');
    return jsonDecode(res.first);
  }

  /// Runs the predicate function on all the items in the table and returns
  /// the first item that the predicate returns true on.
  /// If no elements return true, null is returned
  Future<T?> find(bool Function(T value, int index) predicate) async {
    final entries = await readColumn();

    if (entries.isEmpty) return null;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];

      final predicateResult = predicate(jsonDecode(entry), i);

      if (predicateResult) return jsonDecode(entry);
    }

    return null;
  }

  /// Returns all the entries in the table
  Future<List<T>> getEntries() async {
    final entries = await readColumn();

    if (entries.isEmpty) return [];

    return entries.map((e) => jsonDecode(e)).toList().cast<T>();
  }

  /// Sets the cell at the given index to [T] value
  Future<bool> set(int index, T value) async {
    final encoded = jsonEncode(value);

    final res = await writeRange('$column${index + 1}', [encoded]);

    return res;
  }

  /// Sets a range of cells starting from [startIndex] to the given list of [T] values
  Future<bool> bulkSet(int startIndex, List<T> values) async {
    final encoded = values.map((e) => jsonEncode(values)).toList();

    final res = await writeRange('$column${startIndex + 1}', encoded);

    return res;
  }

  /// Read multiple cells at once
  Future<List<T>> bulkRead(int startIndex, int endIndex) async {
    final inData = await readRange('$column${startIndex + 1}:$column$endIndex');

    final flat = inData.map((e) => jsonDecode(e)).toList();

    return flat.cast<T>();
  }

  /// Returns all the elements in the table
  Future<List<String>> readColumn() async {
    final res = await sheetsClient.sheets.spreadsheets.values.get(
      sheetsClient.ssId,
      '$sheetName!$column:$column',
      majorDimension: 'COLUMNS',
    );

    if (res.values == null) return [];

    final values = res.values!.expand((element) => element).toList();

    return values.cast<String>();
  }

  /// Returns the contents of a selected range of cells
  Future<List<String>> readRange(String range) async {
    notationCheck(range);

    final res = await sheetsClient.sheets.spreadsheets.values.get(
      sheetsClient.ssId,
      '$sheetName!$range',
      majorDimension: 'COLUMNS',
    );

    if (res.values == null) return [];

    final values = res.values!.expand((element) => element).toList();
    return values.cast<String>();
  }

  /// Writes the passed values to the range given
  Future<bool> writeRange(String range, List<String> values) async {
    notationCheck(range);

    List<List<String>> formattedValues = values.map((e) => [e]).toList();

    final res = await sheetsClient.sheets.spreadsheets.values.update(
      ValueRange(
        values: formattedValues,
        majorDimension: 'COLUMNS',
      ),
      valueInputOption: "USER_ENTERED",
      sheetsClient.ssId,
      '$sheetName!$range',
    );

    return res.updatedCells != null ? true : false;
  }

  /// Check if a string is A1 notation valid. If so, throw an error
  void notationCheck(String input) {
    if (a1Validate(input)) return;

    throw ArgumentError.value(input);
  }

  /// Matches any string that is a column
  static RegExp get columnRegex => RegExp(r'^[a-zA-Z]+$');

  /// Matches any string that contains the sheet name, column and row in A1 notation
  static RegExp get a1Regex =>
      RegExp(r'^[a-zA-Z]+[0-9]+$|^[a-zA-Z]+[0-9]+:[a-zA-Z]+[0-9]+$');

  /// Matches any string that contains a column and row in A1 notation
  static RegExp get noSheetA1 =>
      RegExp(r'^[a-zA-Z]+[0-9]+$|^[a-zA-Z]+[0-9]+:[a-zA-Z]+[0-9]+$');

  /// Matches any singular cell in a sheet
  static RegExp get oneCellA1 => RegExp(r'^[a-zA-z]+[0-9]+$');

  /// Check if a string has correct A1 notation syntax using the [a1Regex] Regex
  static bool a1Validate(String value) {
    return a1Regex.hasMatch(value);
  }
}
