import 'dart:async';
import 'dart:convert';
import 'package:googleapis/shared.dart';
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

/// Provides low level functions for reading and writing to a sheet.
/// It's best recommended not to use this unless all other methods
/// of using a sheet is not fit for your use.
class SheetInteractionHandler {
  final String sheetName;
  final String spreadsheetId;
  final SpreadsheetsValuesResource spreadsheetValues;

  SheetInteractionHandler({
    required this.spreadsheetId,
    required this.spreadsheetValues,
    required this.sheetName,
  });

  /// Clears a single range and returns whether it was a success
  Future<bool> clearRange(String range) async {
    notationCheck(range);

    // How tf do you not use this $Empty class????
    final res = await spreadsheetValues.clear($Empty(), spreadsheetId, range);

    return res.clearedRange != null;
  }

  /// Returns all the elements in the table
  Future<List<String>> readColumn(String column) async {
    if (!columnRegex.hasMatch(column)) {
      throw ArgumentError('Column "$column" isn\'t a column.');
    }

    final res = await spreadsheetValues.get(
      spreadsheetId,
      '$sheetName!$column:$column',
      majorDimension: 'COLUMNS',
    );

    if (res.values == null) return [];

    final values = res.values!.expand((element) => element).toList();

    return values.cast<String>();
  }

  /// Returns the contents of a selected range of cells.
  /// Excludes all null cells.
  Future<List<List<String>>> readRange(String range) async {
    notationCheck(range);

    final res = await spreadsheetValues.get(
      spreadsheetId,
      '$sheetName!$range',
      majorDimension: 'COLUMNS',
    );

    if (res.values == null) return [];

    final rows = res.values!;
    List<List<String>> cells = [];

    for (final row in rows) {
      List<String> filteredRow = row.whereType<String>().toList();
      cells.add(filteredRow);
    }

    return cells;
  }

  /// Reads a singular cell given it's coordinate
  Future<String?> readCell(String cellCoordinate) async {
    if (!oneCellA1.hasMatch(cellCoordinate)) {
      throw ArgumentError('$cellCoordinate is not a valid cell');
    }

    final raw = await readRange(cellCoordinate);
    if (raw.isEmpty) return null;

    final flattened = raw.expand((element) => element).toList();
    if (flattened.isEmpty) return null;

    return flattened.first;
  }

  /// Writes the passed values to the range given.
  /// It takes in a 2D array with the nested arrays being the rows.
  Future<bool> writeRange(String range, List<List<String>> values) async {
    notationCheck(range);

    final res = await spreadsheetValues.update(
      ValueRange(
        values: values,
        majorDimension: 'COLUMNS',
      ),
      valueInputOption: "USER_ENTERED",
      spreadsheetId,
      '$sheetName!$range',
    );

    return res.updatedCells != null ? true : false;
  }

  Future<bool> appendAtRange(String range, List<List<String>> values) async {
    final res = await spreadsheetValues.append(
      ValueRange(
        values: values,
        majorDimension: 'COLUMNS',
      ),
      spreadsheetId,
      '$sheetName!$range',
      valueInputOption: "USER_ENTERED",
    );

    return res.updates?.updatedCells != null ? true : false;
  }

  /// Check if a string is A1 notation valid. If so, throw an error
  void notationCheck(String input) {
    if (noSheetA1.hasMatch(input)) return;

    throw ArgumentError.value(input);
  }

  /// Matches any string that is a column
  static RegExp get columnRegex => RegExp(r'^[a-zA-Z]+$');

  /// Matches any string that contains the sheet name, column and row in A1 notation
  static RegExp get a1Regex => RegExp(r'^.+![a-zA-Z]+[0-9]+:[a-zA-Z]+[0-9]+$');

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

/// A table to store data in represented as a column in sheets
class SheetColumn<T> extends SheetInteractionHandler {
  SheetColumn({
    required this.sheetsClient,
    required this.column,
    required this.decodeFunction,
    required super.sheetName,
  }) : super(
          spreadsheetId: sheetsClient.ssId,
          spreadsheetValues: sheetsClient.sheets.spreadsheets.values,
        );

  final SheetsClient sheetsClient;
  final String column;
  final T Function(String rawValue) decodeFunction;

  /// Retrieves the item at the specified index (Row).
  /// Index starts at 0
  Future<T?> at(int index) async {
    final res = await readCell('$column${index + 1}');
    if (res == null) return null;
    return decodeFunction(res);
  }

  /// Runs the predicate function on all the items in the table and returns
  /// the first item that the predicate returns true on.
  /// If no elements return true, null is returned
  Future<T?> find(bool Function(T value, int index) predicate) async {
    final entries = await readColumn(column);

    if (entries.isEmpty) return null;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final decodedEntry = decodeFunction(entry);

      final predicateResult = predicate(decodedEntry, i);

      if (predicateResult) return decodedEntry;
    }

    return null;
  }

  /// Read multiple cells at once
  Future<List<T>> bulkRead(int startIndex, int endIndex) async {
    final inData =
        await readRange('$column${startIndex + 1}:$column${endIndex + 1}');
    final flattened = inData.expand((element) => element).toList();

    final flat = flattened.map((e) => decodeFunction(e)).toList();

    return flat.cast<T>();
  }

  /// Sets a range of cells starting from [startIndex] to the given list of [T] values
  Future<bool> bulkSet(int startIndex, List<String> values) async {
    final encoded = values.map((e) => jsonEncode(e)).toList();
    final formatted = [
      [...encoded]
    ];

    final res = await writeRange('$column${startIndex + 1}', formatted);

    return res;
  }

  /// Returns all the entries in the table
  Future<List<T>> getEntries() async {
    final entries = await readColumn(column);

    if (entries.isEmpty) return [];

    final filtered =
        entries.whereType<String>().where((element) => element.isNotEmpty);

    return filtered.map((e) => decodeFunction(e)).cast<T>().toList();
  }

  /// Sets the cell at the given index to [T] value
  Future<bool> set(int index, T value) async {
    final encoded = jsonEncode(value);

    final res = await writeRange('$column${index + 1}', [
      [encoded]
    ]);

    return res;
  }

  /// Deletes an entry and returns true if the entry existed
  Future<bool> delete(int index) async {
    final success = await clearRange(
      '$column${index + 1}',
    );
    return success;
  }
}

/// A map of keys and values. Very similar to the javascript Map
class SheetMap<K, V> extends SheetInteractionHandler {
  final String keyColumn;
  final String valueColumn;
  final SheetsClient client;
  final V Function(String rawValue) decodeFunction;

  SheetMap({
    required this.client,
    required super.sheetName,
    required this.keyColumn,
    required this.valueColumn,
    required this.decodeFunction,
  }) : super(
          spreadsheetId: client.ssId,
          spreadsheetValues: client.sheets.spreadsheets.values,
        );

  /// Deletes an entry and returns true if the entry existed
  Future<bool> delete(K key) async {
    final index = await _indexOfKey(key);
    if (index < 0) return false;

    final success = await clearRange(
      '$keyColumn${index + 1}:$valueColumn${index + 1}',
    );
    return success;
  }

  /// Updates a value if the key is already in the map otherwise it will
  /// a new entry
  Future<bool> set(K key, V value) async {
    final encodedKey = jsonEncode(key);
    final encodedValue = jsonEncode(value);

    final keyIndex = await _indexOfKey(key);
    if (keyIndex < 0) {
      return await appendAtRange(
        '$keyColumn:$keyColumn',
        [
          [encodedKey], // Key Column
          [encodedValue],
        ],
      );
    }

    // Update key value
    return await writeRange('$valueColumn${keyIndex + 1}', [
      [encodedValue]
    ]);
  }

  /// Retrieves a value given a key. If no value is found, null is returned.
  Future<V?> get(K key) async {
    final index = await _indexOfKey(key);
    if (index < 0) return null;
    final raw = await readCell('$valueColumn${index + 1}');
    if (raw == null) return null;

    return decodeFunction(raw);
  }

  Future<bool> has(K key) async => await _indexOfKey(key) > -1;

  Future<List<K>> allKeys([K Function(String rawValue)? decode]) async {
    final column = await readColumn(keyColumn);
    final keys = column.map((e) => decode != null ? decode(e) : jsonDecode(e));
    return keys.cast<K>().toList();
  }

  Future<List<V>> allValues() async {
    final column = await readColumn(valueColumn);
    final values = column.map((e) => decodeFunction(e));
    return values.cast<V>().toList();
  }

  Future<int> _indexOfKey(K key) async {
    final encodedKey = jsonEncode(key);
    final keys = await readColumn(keyColumn);
    return keys.indexOf(encodedKey);
  }
}
