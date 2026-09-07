import 'dart:convert';

import 'package:googleapis/sheets/v4.dart';
import 'package:sheets_store/sheets_store.dart';

/// Treats a whole sheet as a giant map where each column is a key
/// and each row is a map of values.
/// This can result in more human-readable sheets instead of
/// the sheet acting just as a bare bones database.
class SheetTable<K extends Object?, V extends Object?>
    extends SheetInteractionHandler {
  SheetTable({
    required this.client,
    required super.sheetName,
    this.decodeFunction = jsonDecode,
    this.encodeFunction = jsonEncode,
  }) : super(
         spreadsheetId: client.ssId,
         spreadsheetValues: client.sheets.spreadsheets.values,
       );

  final SheetsClient client;
  final Object? Function(String rawValue) decodeFunction;
  final String Function(Object? values) encodeFunction;

  final base24 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  String _base10Convert(int value, String baseDigits) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Must be non-negative');
    }

    // we'll do a do‑while so that 0 → A comes out right
    var result = '';
    var v = value;
    do {
      // remainder in [0, baseDigits.length‑1]
      final rem = v % baseDigits.length;
      result = baseDigits[rem] + result;
      // shift down, subtracting 1 so that e.g. Z→AA instead of Z→BA
      v = (v ~/ baseDigits.length) - 1;
    } while (v >= 0);

    return result;
  }

  Future<List<String>> _getEncodedKeys() async {
    // Read all cells of first row
    final res = await spreadsheetValues.get(
      spreadsheetId,
      '$sheetName!A1:1',
      majorDimension: 'ROWS',
    );

    return explodeValues(res.values);
  }

  // Keys are written in the row column
  /// Returns an object with keys as the object keys written by user
  /// and values as the column names for those object keys
  ///
  /// Example:
  /// ---
  /// Object keys: name, lastName, age, phone
  ///
  /// Respective Columns: A, B, C, D
  ///
  /// Function Returns: {"name": "A", "lastName": "B", "age": "C", "phone": "D"}
  Future<Map<String, String>> getKeyAssignments() async {
    Map<String, String> assignedKeys = {};

    final encodedKeys = await _getEncodedKeys();

    // with a major dimension of rows we can
    // get the cells in the first row in one array
    for (int i = 0; i < encodedKeys.length; i++) {
      final key = encodedKeys[i];
      final expectedColumn = _base10Convert(i, base24);
      if (key.isNotEmpty) {
        assignedKeys[key] = expectedColumn;
      }
    }

    return assignedKeys;
  }

  Map<K, V> _decode(Map<String, String> values) {
    return values.map<K, V>((key, value) {
      return MapEntry(decodeFunction(key) as K, decodeFunction(value) as V);
    });
  }

  Map<String, String> _encode(Map<K, V> values) {
    return values.map<String, String>((key, value) {
      return MapEntry(encodeFunction(key), encodeFunction(value));
    });
  }

  /// Converts a kew to its assigned column
  Future<String?> keyToColumn(K key) async {
    final encodedKey = encodeFunction(key);
    final assignedKeys = await getKeyAssignments();
    return assignedKeys[encodedKey];
  }

  /// Ensures the keys are added to the row without overriding other keys
  Future<Map<String, String>> _addKeysToSheet(List<String> encodedKeys) async {
    // Columns in the key row where the cell is empty
    final List<int> emptyColumnIndexes = [];
    final keyRow = await _getEncodedKeys();
    // Find all indexes where the cell is empty
    for (int i = 0; i < keyRow.length; i++) {
      final cell = keyRow[i];

      if (cell.isNotEmpty) continue;
      emptyColumnIndexes.add(i);
    }

    // first safe (empty) cell index we can use
    final safeOffset = emptyColumnIndexes.isEmpty
        ? keyRow.length
        : emptyColumnIndexes.first;

    // this is the payload passed in the batchUpdate request that
    // contains all the ranges with their data to be updated
    final List<ValueRange> emptyColumnsPayload = [];

    final Map<String, String> keysWithTheirAssignedColumns = {};

    for (int i = 0; i < encodedKeys.length; i++) {
      // In cases like an empty key row the get request
      // made will only return an empty array in which case
      // we know that we can just use any index we want
      final int columnIndex;
      if (emptyColumnIndexes.length - 1 < i) {
        columnIndex = i + safeOffset;
      } else {
        columnIndex = emptyColumnIndexes[i];
      }

      final column = _base10Convert(columnIndex, base24);

      emptyColumnsPayload.add(
        ValueRange(
          range: '$sheetName!${column}1',
          values: [
            [encodedKeys[i]],
          ],
        ),
      );

      keysWithTheirAssignedColumns[encodedKeys[i]] = column;
    }

    await spreadsheetValues.batchUpdate(
      BatchUpdateValuesRequest(
        data: emptyColumnsPayload,
        valueInputOption: 'USER_ENTERED',
      ),
      spreadsheetId,
    );

    return keysWithTheirAssignedColumns;
  }

  /// Gets the first WRITE-ABLE row
  Future<int> _getFirstFreeRow() async {
    final res = await spreadsheetValues.get(
      spreadsheetId,
      sheetName,
      majorDimension: MajorDimension.rows.name,
    );

    if (res.values == null) return 2;

    // Check if there is an empty space between other rows. If not,
    // then write at the row after the last one
    final firstEmptyRow = res.values!.indexWhere((row) => row.isEmpty);
    if (firstEmptyRow < 0) return res.values!.length + 1;

    return firstEmptyRow + 1;
  }

  Future<List<String>> _readRow(int row) async {
    final res = await spreadsheetValues.get(
      spreadsheetId,
      '$sheetName!$row:$row',
      majorDimension: MajorDimension.rows.name,
    );

    return explodeValues(res.values);
  }

  /// Gets all the filled in fields at [row]
  Future<Map<K, V>> at(int row) async {
    _rowCheck(row);
    final cells = await _readRow(row);
    final keys = await _getEncodedKeys();

    Map<String, String> stringifiedRow = {};

    for (int i = 0; i < cells.length; i++) {
      final cell = cells[i];
      if (cell.isEmpty) continue;

      stringifiedRow[keys[i]] = cell;
    }

    return _decode(stringifiedRow);
  }

  /// Get a specific value at a specific row from a specific key
  // Name might change but it's kinda silly icl
  Future<V?> pick(K key, int row) async {
    _rowCheck(row);
    final column = await keyToColumn(key);
    if (column == null) return null;

    final encodedValue = await readCell('$column$row');
    if (encodedValue == null) return null;
    final decoded = decodeFunction(encodedValue);

    return decoded as V;
  }

  /// Returns all non-null values assigned to given key
  Future<List<V>> valuesOfKey(K key) async {
    final columnOfKey = await keyToColumn(key);

    if (columnOfKey == null) {
      throw ArgumentError.value(columnOfKey, "key", "Key does not exist");
    }

    final encodedValues = await readColumn(columnOfKey);

    // decode only values and skip index 0 (first row/key)
    final decodedValues = encodedValues
        .sublist(1)
        .map((e) => e.isNotEmpty ? decodeFunction(e) : null);

    return decodedValues.where((element) => element != null).cast<V>().toList();
  }

  Future<Map<K, List<V>>?> valuesOfKeys(List<K> keys) async {
    final keysAsColumns = await getKeyAssignments();

    final res = await spreadsheetValues.batchGet(
      spreadsheetId,
      majorDimension: MajorDimension.columns.name,
      ranges: keys
          .map((e) {
            final encoded = encodeFunction(e);
            final associatedColumn = keysAsColumns[encoded];

            if (associatedColumn == null) return null;
            return '$sheetName!${associatedColumn}2:$associatedColumn';
          })
          .whereType<String>()
          .toList(),
    );

    if (res.valueRanges == null) return null;

    final map = <K, List<V>>{};

    for (int i = 0; i < res.valueRanges!.length; i++) {
      final valueRange = res.valueRanges![i];
      final flattened = explodeValues(
        valueRange.values,
      ).where((e) => e.isNotEmpty);

      map[keys[i]] = flattened.map(decodeFunction).cast<V>().toList();
    }

    return map;
  }

  /// Adds values to a specific key in new rows
  Future<bool> appendAtKey(K key, List<V> values) async {
    final columnOfKey = await keyToColumn(key);

    if (columnOfKey == null) {
      throw ArgumentError.value(columnOfKey, "key", "Key does not exist");
    }

    final firstFreeRow = await _getFirstFreeRow();

    final res = await spreadsheetValues.batchUpdate(
      BatchUpdateValuesRequest(
        data: [
          ValueRange(
            majorDimension: MajorDimension.columns.name,
            range: '$sheetName!$columnOfKey$firstFreeRow:$columnOfKey',
            values: [values.map(encodeFunction).toList()],
          ),
        ],
        valueInputOption: 'USER_ENTERED',
      ),
      spreadsheetId,
    );

    return res.totalUpdatedCells == values.length;
  }

  /// Note: Missing keys will added
  Future<bool> update(int row, Map<K, V> values) async {
    _rowCheck(row);
    final encoded = _encode(values);

    final assignedKeys = await getKeyAssignments();
    final existingKeys = assignedKeys.keys
        .where((key) => encoded.containsKey(key))
        .toList();

    final missingKeys = encoded.keys
        .where((key) => !existingKeys.contains(key))
        .toList();

    final missingAssignedKeys = await _addKeysToSheet(missingKeys);
    final mKeyEntries = missingAssignedKeys.entries.toList();
    // add missing keys to the assigned keys map
    for (final entry in mKeyEntries) {
      assignedKeys[entry.key] = entry.value;
    }

    // now that we have all the keys that [encoded] has we can go key by key
    // and find their respective columns to add their value to. Oh and make
    // batchUpdate request
    final List<ValueRange> payload = [];

    for (MapEntry<String, String> assignedKey in assignedKeys.entries) {
      payload.add(
        ValueRange(
          range: '$sheetName!${assignedKey.value}$row',
          values: [
            [encoded[assignedKey.key]],
          ],
        ),
      );
    }

    final res = await spreadsheetValues.batchUpdate(
      BatchUpdateValuesRequest(data: payload, valueInputOption: 'USER_ENTERED'),
      spreadsheetId,
    );

    return res.totalUpdatedCells != null ? true : false;
  }

  /// Appends to the first row with no keys having any values
  /// and returns the row the values were appended to
  Future<int> append(Map<K, V> values) async {
    final firstFreeRow = await _getFirstFreeRow();
    await update(firstFreeRow, values);

    return firstFreeRow;
  }

  /// Warning!
  /// ---
  /// This function deletes the key AND all associated values
  Future<bool> deleteKey(K key) async {
    final column = await keyToColumn(key);

    final didSucceed = await clearRange('$column:$column');

    return didSucceed;
  }

  /// Clears the whole sheet
  Future<bool> clear() async {
    final res = await spreadsheetValues.clear(
      ClearValuesRequest(),
      spreadsheetId,
      sheetName,
    );

    return res.clearedRange != null;
  }

  /// Essentially clears a whole row
  ///
  /// Note: First row is 2 as row 1 is reserved as the key row
  Future<bool> deleteEntry(int row) async {
    _rowCheck(row);
    final didSucceed = await clearRange('$row:$row');

    return didSucceed;
  }

  Future<bool> hasKey(K key) async {
    return await keyToColumn(key) != null;
  }

  Future<K?> findKey(bool Function(K key) test) async {
    final allKeys = await getKeyAssignments();

    K? searchHit;

    for (final key in allKeys.keys) {
      final decoded = decodeFunction(key) as K;

      if (test(decoded)) {
        searchHit = decoded;
        break;
      }
    }

    return searchHit;
  }

  // This is essentially a wrapper
  Future<List<K>> findKeys(bool Function(K key) test) async {
    final allKeys = await getKeyAssignments();
    final hits = allKeys.keys.map(decodeFunction).cast<K>().where(test);

    return hits.toList();
  }

  /// Tests your [test] function against all entries in the table and
  /// returns the first hit
  ///
  /// If no hit exists it returns null
  Future<Map<K, V>?> findEntry(
    bool Function(Map<K, V> entry, int row) test,
  ) async {
    final allRows = await spreadsheetValues.get(
      spreadsheetId,
      sheetName,
      majorDimension: MajorDimension.rows.name,
    );

    if (allRows.values == null) return null;

    Map<K, V>? firstHit;

    final keyAssignments = await getKeyAssignments();
    final decodedKeys = keyAssignments.keys
        .map(decodeFunction)
        .cast<K>()
        .toList();

    // Start from row 2 (index 1) to avoid the key row (row 1, index 0)
    for (int i = 1; i < allRows.values!.length; i++) {
      final encodedEntryValues = allRows.values![i];
      // A LOT of filtering and we can decode them
      final decoded = encodedEntryValues
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .map(decodeFunction)
          .cast<V>()
          .toList();

      // Constructed map from decoded values and keys
      final constructed = <K, V>{};

      for (int j = 0; j < decoded.length; j++) {
        constructed[decodedKeys[j]] = decoded[j];
      }

      if (test(constructed, i + 1)) {
        firstHit = constructed;
        break;
      }
    }

    return firstHit;
  }

  /// Throw an error if the user attempts to read row 1 (reserved key row)
  ///
  /// Note:
  /// -
  /// This does not expect rows using 0-based indexes
  void _rowCheck(int row) {
    if (row < 2) {
      throw ArgumentError.value(
        row,
        'row',
        'Cannot read/write at rows 1 or below. Given row',
      );
    }

    return;
  }
}
