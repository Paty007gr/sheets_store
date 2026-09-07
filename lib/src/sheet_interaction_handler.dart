import 'package:googleapis/sheets/v4.dart';
import 'package:sheets_store/sheets_store.dart';

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
  ///
  /// *Sheet name does not need to be provided*
  Future<bool> clearRange(String range) async {
    final res = await spreadsheetValues.clear(
      ClearValuesRequest(),
      spreadsheetId,
      '$sheetName!$range',
    );

    return res.clearedRange != null;
  }

  /// Takes in a range of values and puts all the values
  /// in a singular array. This is useful when requesting
  /// a row or column where all nested arrays contain a single
  /// value.
  ///
  /// Note: Empty cells or cells that are null are turned
  /// into empty strings
  List<String> explodeValues(List<List<Object?>>? values) {
    if (values == null) return [];

    final expanded = values.expand((e) => e).map((e) => e ?? '').toList();

    return expanded.cast<String>();
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
  Future<List<List<String>>> readRange(
    String range, {
    MajorDimension dimension = MajorDimension.columns,
  }) async {
    final res = await spreadsheetValues.get(
      spreadsheetId,
      '$sheetName!$range',
      majorDimension: dimension.name,
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
  Future<bool> writeRange(
    String range,
    List<List<String>> values, {
    MajorDimension majorDimension = MajorDimension.columns,
  }) async {
    final res = await spreadsheetValues.update(
      ValueRange(values: values, majorDimension: majorDimension.name),
      valueInputOption: "USER_ENTERED",
      spreadsheetId,
      '$sheetName!$range',
    );

    return res.updatedCells != null ? true : false;
  }

  Future<bool> appendAtRange(String range, List<List<String>> values) async {
    final res = await spreadsheetValues.append(
      ValueRange(values: values, majorDimension: 'COLUMNS'),
      spreadsheetId,
      '$sheetName!$range',
      valueInputOption: "USER_ENTERED",
    );

    return res.updates?.updatedCells != null ? true : false;
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
