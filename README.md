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

You can use these like an array.
```dart
myColumn.at(0); // Reads Row 1
myColumn.set(0, 'newValue'); // Set/Update a value at an index
myColumn.append('newestValue'); // Add to the first free row in the column
myColumn.delete(0); // Delete Values to clear cells
myColumn.find(...); // find a value based on a test function

// more functions included. Look into the code or the list of methods
// provided by your intellisense/autocomplete.
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

```dart
// Retrieves a value given a key. If no value is found, null is returned.
map.get('key');

// Does a key exist
map.has('age'); // false

// Updates a value if the key is already in the map 
// otherwise it will add a new entry
map.set('age', 92);

map.delete('key'); // Delete a key with its value

// more functions included. Look into the code or the list of methods
// provided by your intellisense/autocomplete.
```

## Tables

Tables are like the supercharged version of `SheetMap`s. Each map key gets its own column (referred to as associated column or object key column) and the values for that key are placed in that column past row 1 (referred to as key row) that is reserved for actually holding the map key.

It can be initialized as shown in the example below.

```dart
// It is recommended you use specific types
// instead of leaving them ambagious
final table = SheetTable<String, num>(
  client: client,
  sheetName: 'Test Sheet',
);
```

Notice we are no longer specifying key or value columns. That's because **Sheet tables use the whole sheet not just space you reserve for it**. If you wish to store more data in the spreadsheet you need to create other sheets otherwise you risk overwriting data.


Usage of tables:

```dart
// Reads all values with their keys at row 2 (row 1 is reserved)
table.at(1);

// This will place 92 at row 1 under the column for age
// and 9999... at row 1 under the column for phone
// If the keys don't exist they will be created on demand
table.update(1, {'age': 92, 'phone': 999999999});

// Will give you all values in all rows with their respective keys
// and return the first entry that passes your test function
table.findEntry(...);

// clears the WHOLE sheet
table.clear();

// Delete all values in row 1
table.deleteEntry(1);

// many more functions included. View source code or intellisense/autocorrect
```