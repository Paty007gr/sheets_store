## 2.1.1

- Bumped dependencies and dart version (now ^3.8.0)

## 2.1.0

- New class `SheetTable` look into README for more info
- `SheetColumn` now has a new length getter which asynchronously returns you the length of the column
- Updated some of the code documentation

Possibly breaking changes:
- `SheetInteractionHandler.clear` no longer does a notation check and automatically prefixes the sheet name to the range

## 2.0.0

- New class `SheetMap` that allows you to store data as a map
- New class `SheetInteractionHandler` for more precise control of a sheet
- Renamed `Table` to `SheetColumn` as the old name wasn't as clear and also interfered with the Flutter widget `Table` causing import inconveniences
- Fixed `SheetColumn` encoding input data twice when writing to a sheet
- Changed package description (Previous one was incomplete)
- Added the ability to delete/clear cells


## 1.0.0

- Initial version.
