import 'dart:async';

import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/sheets/v4.dart';

export 'package:sheets_store/src/sheet_column.dart';
export 'package:sheets_store/src/sheet_table.dart';
export 'package:sheets_store/src/sheet_map.dart';
export 'package:sheets_store/src/sheet_interaction_handler.dart';

enum MajorDimension {
  columns('COLUMNS'),
  rows('ROWS');

  const MajorDimension(this.name);

  final String name;
}

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
    String targetSpreadsheetId,
    Object? jsonCredentials,
  ) async {
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
