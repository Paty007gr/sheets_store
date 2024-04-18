An easy to use and simple way to store data in google sheets

## Usage

To use this package you first need to set up a google cloud project. Then enable the Google Sheets API in the APIs & Services. Once you have done that go to credentials and create a service account with a JSON key. Put the JSON key in your workspace directory. Remember to use .gitignore if you are uploading your code to github or sharing your project with anyone else.

Create a spreadsheet in google drive and share it with your service account. Then go into your code and use the code below to initiate a `SheetsClient`.

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

With the `SheetsClient` you can create tables, the package's representation of columns. They function pretty much like giant arrays. To create one use the code below.

```dart
// here we are creating a table (aka a column) that will be filled with string values
// but it can really be anything that jsonEncode can actually encode
final table = Table<String>(
    column: 'Column of choice here',
    sheetName: 'Whatever your sheet\'s name is, something like Sheet1',
    sheetsClient: client,
);
```

Using tables you can read and write to a sheet. See the example given for the complete code.