import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;

/// Centralized export service – Excel (.xlsx) and PNG screenshot.
class ExportService {
  ExportService._();

  // ─── Excel helpers ──────────────────────────────────────────────────────

  /// Create an Excel workbook with a single sheet from rows of data.
  /// [sheetName] – name shown on the tab.
  /// [headers]   – column header strings.
  /// [rows]      – list of rows; each row is a list of cell values.
  /// Returns the encoded bytes ready for download.
  static Uint8List buildExcel({
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    // Remove default "Sheet1" if it exists and is not our sheet
    if (sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    // Header row with bold style
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
    }

    // Data rows
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is int) {
          cell.value = IntCellValue(v);
        } else if (v is double) {
          cell.value = DoubleCellValue(v);
        } else {
          cell.value = TextCellValue(v?.toString() ?? '');
        }
      }
    }

    // Auto-fit rough column widths
    for (var c = 0; c < headers.length; c++) {
      var maxLen = headers[c].length;
      for (final row in rows) {
        if (c < row.length) {
          final len = (row[c]?.toString() ?? '').length;
          if (len > maxLen) maxLen = len;
        }
      }
      sheet.setColumnWidth(c, (maxLen + 4).toDouble().clamp(10, 50));
    }

    return Uint8List.fromList(excel.encode()!);
  }

  /// Build Excel with multiple sheets.
  static Uint8List buildExcelMultiSheet(List<ExcelSheetData> sheets) {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    for (final s in sheets) {
      final sheet = excel[s.name];
      for (var c = 0; c < s.headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(s.headers[c]);
        cell.cellStyle = headerStyle;
      }
      for (var r = 0; r < s.rows.length; r++) {
        for (var c = 0; c < s.rows[r].length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
          final v = s.rows[r][c];
          if (v is int) {
            cell.value = IntCellValue(v);
          } else if (v is double) {
            cell.value = DoubleCellValue(v);
          } else {
            cell.value = TextCellValue(v?.toString() ?? '');
          }
        }
      }
      for (var c = 0; c < s.headers.length; c++) {
        var maxLen = s.headers[c].length;
        for (final row in s.rows) {
          if (c < row.length) {
            final len = (row[c]?.toString() ?? '').length;
            if (len > maxLen) maxLen = len;
          }
        }
        sheet.setColumnWidth(c, (maxLen + 4).toDouble().clamp(10, 50));
      }
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Download helpers (web) ─────────────────────────────────────────────

  /// Trigger browser download of an Excel file.
  static void downloadExcel(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Trigger browser download of a PNG file.
  static void downloadPng(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ─── PNG capture ────────────────────────────────────────────────────────

  /// Capture a widget wrapped in a RepaintBoundary as PNG bytes.
  /// Pass the GlobalKey attached to the RepaintBoundary.
  static Future<Uint8List?> capturePng(GlobalKey key, {double pixelRatio = 2.0}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ─── Convenience: one-tap export with SnackBar feedback ─────────────────

  static Future<void> exportExcelAndNotify({
    required BuildContext context,
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String filePrefix,
  }) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có dữ liệu để xuất')),
      );
      return;
    }
    final bytes = buildExcel(sheetName: sheetName, headers: headers, rows: rows);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    downloadExcel(bytes, '${filePrefix}_$stamp.xlsx');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xuất $sheetName (${ rows.length} dòng)'), backgroundColor: Colors.green),
      );
    }
  }

  static Future<void> exportMultiSheetAndNotify({
    required BuildContext context,
    required List<ExcelSheetData> sheets,
    required String filePrefix,
    required String label,
  }) async {
    final totalRows = sheets.fold<int>(0, (sum, s) => sum + s.rows.length);
    if (totalRows == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có dữ liệu để xuất')),
      );
      return;
    }
    final bytes = buildExcelMultiSheet(sheets);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    downloadExcel(bytes, '${filePrefix}_$stamp.xlsx');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xuất $label ($totalRows dòng)'), backgroundColor: Colors.green),
      );
    }
  }

  static Future<void> exportPngAndNotify({
    required BuildContext context,
    required GlobalKey captureKey,
    required String filePrefix,
    double pixelRatio = 2.0,
  }) async {
    final bytes = await capturePng(captureKey, pixelRatio: pixelRatio);
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể chụp màn hình')),
        );
      }
      return;
    }
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    downloadPng(bytes, '${filePrefix}_$stamp.png');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xuất ảnh PNG'), backgroundColor: Colors.green),
      );
    }
  }
}

/// Data for one sheet in a multi-sheet workbook.
class ExcelSheetData {
  final String name;
  final List<String> headers;
  final List<List<dynamic>> rows;
  const ExcelSheetData({required this.name, required this.headers, required this.rows});
}
