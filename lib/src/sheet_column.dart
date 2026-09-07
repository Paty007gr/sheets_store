import 'dart:convert';

import 'package:sheets_store/sheets_store.dart';

/// A table to store data in represented as a column in sheets
class SheetColumn<T extends Object?> extends SheetInteractionHandler {
  SheetColumn({
    required this.sheetsClient,
    required this.column,
    this.decodeFunction,
    this.encodeFunction,
    required super.sheetName,
  }) : super(
         spreadsheetId: sheetsClient.ssId,
         spreadsheetValues: sheetsClient.sheets.spreadsheets.values,
       );

  final SheetsClient sheetsClient;
  final String column;
  final String Function(T rawValue)? encodeFunction;
  final T Function(String value)? decodeFunction;

  T _decode(String value) {
    if (decodeFunction != null) return decodeFunction!(value);
    return jsonDecode(value);
  }

  String _encode(T value) {
    if (encodeFunction != null) return encodeFunction!(value);
    return jsonEncode(value);
  }

  Future<int> get length async {
    final allEntries = await getEntries();
    return allEntries.length;
  }

  /// Retrieves the item at the specified index (Row).
  /// Index starts at 0
  Future<T?> at(int index) async {
    final res = await readCell('$column${index + 1}');
    if (res == null) return null;
    return _decode(res);
  }

  /// Runs the predicate function on all the items in the table and returns
  /// the first item that the predicate returns true on.
  /// If no elements return true, null is returned
  Future<T?> find(bool Function(T value, int index) predicate) async {
    final entries = await readColumn(column);

    if (entries.isEmpty) return null;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final decodedEntry = _decode(entry);

      final predicateResult = predicate(decodedEntry, i);

      if (predicateResult) return decodedEntry;
    }

    return null;
  }

  /// Read multiple cells at once
  Future<List<T>> bulkRead(int startIndex, int endIndex) async {
    final inData = await readRange(
      '$column${startIndex + 1}:$column${endIndex + 1}',
    );
    final flattened = inData.expand((element) => element).toList();

    final flat = flattened.map((e) => _decode(e)).toList();

    return flat.cast<T>();
  }

  /// Sets a range of cells starting from [startIndex] to the given list of [T] values
  Future<bool> bulkSet(int startIndex, List<T> values) async {
    final encoded = values.map((e) => _encode(e)).toList();
    final formatted = [
      [...encoded],
    ];

    final res = await writeRange('$column${startIndex + 1}', formatted);

    return res;
  }

  /// Returns all the entries in the table
  Future<List<T>> getEntries() async {
    final entries = await readColumn(column);

    if (entries.isEmpty) return [];

    final filtered = entries.whereType<String>().where(
      (element) => element.isNotEmpty,
    );

    return filtered.map((e) => _decode(e)).cast<T>().toList();
  }

  /// Sets the cell at the given index to [T] value
  Future<bool> set(int index, T value) async {
    final encoded = _encode(value);

    final res = await writeRange('$column${index + 1}', [
      [encoded],
    ]);

    return res;
  }

  /// Deletes an entry and returns true if the entry existed
  Future<bool> delete(int index) async {
    final success = await clearRange('$column${index + 1}');
    return success;
  }

  /// Appends a value at the end of the column
  Future<bool> append(T value) async {
    final encoded = _encode(value);
    final res = await appendAtRange('$column:$column', [
      [encoded],
    ]);

    return res;
  }

  @override
  String toString() {
    return 'SheetColumn<$T>(column: $column)';
  }
}
