import 'dart:convert';
import 'dart:math';

import 'package:googleapis/sheets/v4.dart';
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
    final allEntries = await values;
    return allEntries.length;
  }

  Future<bool> get isEmpty async {
    final v = await values;
    return v.isEmpty;
  }

  Future<bool> get isNotEmpty async => !await isEmpty;

  Future<T?> get firstOrNull async {
    final cell = await readCell('${column}1');
    if (cell == null) return null;
    return _decode(cell);
  }

  Future<T> get first async {
    final v = await firstOrNull;
    return v!;
  }

  Future<Iterable<T>> get values async {
    final entries = await readColumn(column);

    if (entries.isEmpty) return Iterable.empty();

    final filtered = entries.whereType<String>().where(
      (element) => element.isNotEmpty,
    );

    return filtered.map((e) => _decode(e));
  }

  Future<Iterable<T>> get reversed async {
    final items = await values;
    return items.toList().reversed;
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
    final entries = (await values).toList();

    if (entries.isEmpty) return null;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];

      final predicateResult = predicate(entry, i);

      if (predicateResult) return entry;
    }

    return null;
  }

  Future<int> indexWhere(bool Function(T e) test, [int? start]) async {
    final entries = (await values).toList();

    for (int i = 0; i < entries.length; i++) {
      if (test(entries[i])) return i;
    }

    return -1;
  }

  /// Checks whether the column contains [value]
  Future<bool> contains(T value) async {
    final result = await find((element, index) => value == element);
    return result != null;
  }

  /// Read multiple cells at once
  Future<List<T>> bulkRead(int start, int end) async {
    final inData = await readRange('$column${start + 1}:$column${end + 1}');
    final flattened = inData.expand((element) => element).toList();

    final flat = flattened.map((e) => _decode(e)).toList();

    return flat;
  }

  Future<List<T>> take(int count) async {
    return await bulkRead(0, count);
  }

  /// Sets a range of cells starting from [start] to the given list of [T] values
  Future<bool> bulkSet(int start, List<T> values) async {
    final encoded = values.map((e) => _encode(e)).toList();
    final formatted = [
      [...encoded],
    ];

    final res = await writeRange('$column${start + 1}', formatted);

    return res;
  }

  /// Returns all the entries in the table
  @Deprecated('Deprecated. Use [SheetColumn.values] instead')
  Future<List<T>> getEntries() async {
    final entries = await values;
    return entries.toList();
  }

  /// Sets the cell at the given index to [T] value
  Future<bool> set(int index, T value) async {
    final encoded = _encode(value);

    final res = await writeRange('$column${index + 1}', [
      [encoded],
    ]);

    return res;
  }

  /// Deletes the entry at the index
  ///  and returns true if the entry existed
  Future<bool> delete(int index) async {
    final success = await clearRange('$column${index + 1}');
    return success;
  }

  /// Deletes an entry - returns true if it existed
  Future<bool> removeElement(T element) async {
    final index = await indexWhere((e) => e == element);
    if (index < 0) return false;
    await clearRange('$column${index + 1}');
    return true;
  }

  Future<T> removeLast() async {
    final entries = await values;
    await delete(entries.length - 1);
    return entries.last;
  }

  Future<void> removeRange(int start, int end) async {
    await clearRange('$column${start + 1}:$column${end + 1}');
  }

  Future<void> removeWhere(bool Function(T e) test) async {
    final entries = (await values).toList();

    List<int> indexesToRemove = [];
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (!test(entry)) continue;

      indexesToRemove.add(i);
    }

    await spreadsheetValues.batchClear(
      BatchClearValuesRequest(
        ranges: indexesToRemove.map((e) => '$column$e').toList(),
      ),
      spreadsheetId,
    );
  }

  Future<void> shuffle([Random? random]) async {
    final entries = await values;
    final shuffle = entries.toList();
    shuffle.shuffle(random);
    await clear();
    await appendAll(entries);
  }

  /// Clears the whole column
  Future<void> clear() async {
    await clearRange('$column:$column');
  }

  /// Appends all values to the end of the column
  Future<bool> appendAll(Iterable<T> values) async {
    final res = await appendAtRange('$column:$column', [
      values.map(_encode).toList(),
    ]);

    return res;
  }

  /// Appends a value to the end of the column
  Future<bool> append(T value) async {
    return await appendAll([value]);
  }

  /// Returns a sublist of the main column's items that pass [test]
  Future<Iterable<T>> where(bool Function(T element) test) async {
    final entries = await values;
    return entries.where(test);
  }

  @override
  String toString() {
    return 'SheetColumn<$T>(column: $column)';
  }
}
