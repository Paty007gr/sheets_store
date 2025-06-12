An easy to use and simple way to store data in google sheets

## Usage

To use this package you first need to set up a google cloud project. Then enable the Google Sheets API in the APIs & Services. Once you have done that go to credentials and create a service account with a JSON key. Put the JSON key in your workspace directory. 

#### Remember!
Use .gitignore if you are uploading your code to github or sharing your project with anyone else.

Create a spreadsheet in google drive and **share it with your service account.** Then go into your code and use the code below to initiate a `SheetsClient`.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:sheets_store/sheets_store.dart';

// ...

Map<String, dynamic> readJsonFile(String filePath) {
  final input = File(filePath).readAsStringSync();
  final decoded = jsonDecode(input);
  return decoded;
}

final client = await SheetsClient.fromServiceAccountCredentials(
    // You can find the spreadsheet id in the url when looking at the spreadsheet
    'ENTER YOUR SPREADSHEET ID HERE',
    readJsonFile('ENTER YOUR JSON CREDENTIALS FILE PATH HERE'),
  );
```

## Columns

To control a column in your sheet initialize a new `SheetColumn` as shown in the example below.

```dart
final myColumn = SheetColumn<String>(
  sheetsClient: client,
  column: 'A',
  sheetName: 'Test Sheet',
);
```

## Maps

These are the google sheets equivalent of a dart `Map`. Initialize as shown in the example below.

```dart
final map = SheetMap<String, num>(
  client: client,
  sheetName: 'Test Sheet',
  keyColumn: 'C',
  valueColumn: 'D',
);
```

### Todo:

#### Functions to add to SheetMap
- containsKey

#### Functions to add to SheetTable
- findValue
- findKey
- hasKey
- valuesOfKeys: returns the values for the list of keys given

- Remove keys
- Remove values
- Clear table (Aka clear sheet)
- Remove rows
 