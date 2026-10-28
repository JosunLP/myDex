import 'dart:io';

/// Minimal RFC 4180 parser (quotes, embedded commas/newlines).
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// A CSV table with column names.
class Table {
  Table(this.name, List<List<String>> raw)
    : columns = raw.first,
      rows = [
        for (final r in raw.skip(1))
          if (r.length > 1 || (r.length == 1 && r.first.isNotEmpty))
            {
              for (var i = 0; i < raw.first.length; i++)
                raw.first[i]: i < r.length ? r[i] : '',
            },
      ];

  factory Table.parse(String name, String content) =>
      Table(name, parseCsv(content));

  final String name;
  final List<String> columns;
  final List<Map<String, String>> rows;
}

/// All tables of a source snapshot.
class SourceTables {
  SourceTables(this._tables);

  static Future<SourceTables> load(
    Directory dir,
    Iterable<String> names,
  ) async => SourceTables({
    for (final n in names)
      n: Table.parse(n, await File('${dir.path}/$n.csv').readAsString()),
  });

  final Map<String, Table> _tables;

  List<Map<String, String>> operator [](String name) =>
      (_tables[name] ?? (throw StateError('Missing table: $name'))).rows;
}

extension RowValues on Map<String, String> {
  int integer(String column) {
    final v = this[column];
    final parsed = v == null ? null : int.tryParse(v);
    if (parsed == null) {
      throw FormatException('Column $column: not a number ("$v")');
    }
    return parsed;
  }

  int? optInt(String column) {
    final v = this[column];
    return v == null || v.isEmpty ? null : int.parse(v);
  }

  bool flag(String column) => this[column] == '1';
}
