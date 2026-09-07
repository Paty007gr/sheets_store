import 'dart:convert';

import 'package:sheets_store/src/sheet_interaction_handler.dart';
import 'package:sheets_store/sheets_store.dart';

/// A map of keys and values. Very similar to the javascript Map
class SheetMap<K extends Object, V extends Object>
    extends SheetInteractionHandler {
  final String keyColumn;
  final String valueColumn;
  final SheetsClient client;
  final V Function(String rawValue)? decodeFunction;
  final String Function(Object value)? encodeFunction;

  SheetMap({
    required this.client,
    required super.sheetName,
    required this.keyColumn,
    required this.valueColumn,
    this.decodeFunction,
    this.encodeFunction,
  }) : super(
         spreadsheetId: client.ssId,
         spreadsheetValues: client.sheets.spreadsheets.values,
       );

  V _decode(String value) {
    if (decodeFunction != null) return decodeFunction!(value);
    return jsonDecode(value);
  }

  String _encode(Object value) {
    if (encodeFunction != null) return encodeFunction!(value);
    return jsonEncode(value);
  }

  /// Deletes an entry and returns true if the entry existed
  Future<bool> delete(K key) async {
    final index = await _indexOfKey(key);
    if (index < 0) return false;

    final success = await clearRange(
      '$keyColumn${index + 1}:$valueColumn${index + 1}',
    );
    return success;
  }

  /// Updates a value if the key is already in the map
  /// otherwise it will add a new entry
  Future<bool> set(K key, V value) async {
    final encodedKey = _encode(key);
    final encodedValue = _encode(value);

    final keyIndex = await _indexOfKey(key);
    if (keyIndex < 0) {
      return await appendAtRange('$keyColumn:$keyColumn', [
        [encodedKey], // Key Column
        [encodedValue],
      ]);
    }

    // Update key value
    return await writeRange('$valueColumn${keyIndex + 1}', [
      [encodedValue],
    ]);
  }

  /// Retrieves a value given a key. If no value is found, null is returned.
  Future<V?> get(K key) async {
    final index = await _indexOfKey(key);
    if (index < 0) return null;
    final raw = await readCell('$valueColumn${index + 1}');
    if (raw == null) return null;

    return _decode(raw);
  }

  /// Whether the map contains a key
  Future<bool> has(K key) async => await _indexOfKey(key) > -1;

  Future<List<K>> allKeys([K Function(String rawValue)? decode]) async {
    final column = await readColumn(keyColumn);
    final keys = column.map((e) => decode != null ? decode(e) : jsonDecode(e));
    return keys.cast<K>().toList();
  }

  Future<List<V>> allValues() async {
    final column = await readColumn(valueColumn);
    final values = column.map((e) => _decode(e));
    return values.cast<V>().toList();
  }

  Future<int> _indexOfKey(K key) async {
    final encodedKey = _encode(key);

    final keys = await readColumn(keyColumn);
    return keys.indexOf(encodedKey);
  }
}
