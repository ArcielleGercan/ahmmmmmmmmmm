import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:web/web.dart' as web;

class AdminLeaderboard extends StatefulWidget {
  const AdminLeaderboard({super.key});

  @override
  State<AdminLeaderboard> createState() => _AdminLeaderboardState();
}

class _AdminLeaderboardState extends State<AdminLeaderboard> {
  String selectedMode = "challenge";

  // Leaderboard data
  final List<Map<String, dynamic>> challengeData = [
    {
      "username": "ronald",
      "avatar": "assets/images-avatars/Brainy.png",
      "totalRewards": 12,
      "easy": 6,
      "avg": 3,
      "diff": 3,
      "last": "05/23/2025 15:45",
      "status": "claimed",
    },
    {
      "username": "carla",
      "avatar": "assets/images-avatars/Girl.png",
      "totalRewards": 11,
      "easy": 6,
      "avg": 2,
      "diff": 1,
      "last": "05/23/2025 15:45",
      "status": "pending",
    },
    {
      "username": "clarisse",
      "avatar": "assets/images-avatars/Twirky.png",
      "totalRewards": 9,
      "easy": 3,
      "avg": 3,
      "diff": 3,
      "last": "05/23/2025 15:45",
      "status": "claimed",
    },
    {
      "username": "robert",
      "avatar": "assets/images-avatars/Sneaky-Snake.png",
      "totalRewards": 8,
      "easy": 4,
      "avg": 2,
      "diff": 2,
      "last": "05/23/2025 15:45",
      "status": "pending",
    },
    {
      "username": "jerome",
      "avatar": "assets/images-avatars/Brainy.png",
      "totalRewards": 7,
      "easy": 4,
      "avg": 2,
      "diff": 1,
      "last": "05/23/2025 15:45",
      "status": "claimed",
    },
    {
      "username": "ariel",
      "avatar": "assets/images-avatars/Twirky.png",
      "totalRewards": 5,
      "easy": 3,
      "avg": 2,
      "diff": 0,
      "last": "05/23/2025 15:45",
      "status": "pending",
    },
    {
      "username": "hannah",
      "avatar": "assets/images-avatars/Girl.png",
      "totalRewards": 4,
      "easy": 2,
      "avg": 2,
      "diff": 0,
      "last": "05/23/2025 15:45",
      "status": "claimed",
    },
    {
      "username": "rico",
      "avatar": "assets/images-avatars/Sneaky-Snake.png",
      "totalRewards": 3,
      "easy": 2,
      "avg": 1,
      "diff": 0,
      "last": "05/23/2025 15:45",
      "status": "pending",
    },
    {
      "username": "marie",
      "avatar": "assets/images-avatars/Astronaut.png",
      "totalRewards": 3,
      "easy": 3,
      "avg": 0,
      "diff": 0,
      "last": "05/23/2025 15:45",
      "status": "claimed",
    },
    {
      "username": "jude",
      "avatar": "assets/images-avatars/Astronaut.png",
      "totalRewards": 2,
      "easy": 1,
      "avg": 1,
      "diff": 0,
      "last": "05/23/2025 15:45",
      "status": "pending",
    },
  ];

  final List<Map<String, dynamic>> battleData = [
    {
      "username": "leo",
      "avatar": "assets/images-avatars/Twirky.png",
      "rewards": 1500,
      "easy": 7,
      "avg": 4,
      "diff": 4,
      "last": "05/23/2025 15:45",
      "status": "claimed",
    },
    {
      "username": "mia",
      "avatar": "assets/images-avatars/Whiz-Busy.png",
      "rewards": 1200,
      "easy": 4,
      "avg": 3,
      "diff": 3,
      "last": "05/23/2025 15:45",
      "status": "pending",
    },
    {
      "username": "alex",
      "avatar": "assets/images-avatars/Brainy.png",
      "rewards": 1050,
      "easy": 5,
      "avg": 3,
      "diff": 2,
      "last": "05/22/2025 18:30",
      "status": "claimed",
    },
    {
      "username": "sarah",
      "avatar": "assets/images-avatars/Girl.png",
      "rewards": 890,
      "easy": 4,
      "avg": 2,
      "diff": 2,
      "last": "05/22/2025 14:15",
      "status": "pending",
    },
    {
      "username": "david",
      "avatar": "assets/images-avatars/Sneaky-Snake.png",
      "rewards": 750,
      "easy": 3,
      "avg": 2,
      "diff": 1,
      "last": "05/21/2025 20:45",
      "status": "claimed",
    },
  ];

  List<Map<String, dynamic>> get leaderboardData {
    return selectedMode == "challenge" ? challengeData : battleData;
  }

  void _refreshData() {
    setState(() {
      // Reload the data (in a real app, you'd fetch from backend)
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Leaderboard data refreshed'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _exportData() {
    Map<String, bool> selectedLeaderboards = {
      'challenge': false,
      'battle': false,
    };
    bool selectAll = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Leaderboard Data',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select which leaderboard(s) to export',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Leaderboard',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text(
                      'Select All',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    value: selectAll,
                    onChanged: (value) {
                      setDialogState(() {
                        selectAll = value ?? false;
                        selectedLeaderboards['challenge'] = selectAll;
                        selectedLeaderboards['battle'] = selectAll;
                      });
                    },
                    activeColor: const Color(0xFF046EB8),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    title: const Text(
                      'Badges',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                    ),
                    secondary: const Icon(
                      Icons.emoji_events,
                      color: Color(0xFF046EB8),
                    ),
                    value: selectedLeaderboards['challenge'],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedLeaderboards['challenge'] = value ?? false;
                        selectAll =
                            selectedLeaderboards['challenge']! &&
                                selectedLeaderboards['battle']!;
                      });
                    },
                    activeColor: const Color(0xFF046EB8),
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'Stars',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                    ),
                    secondary: const Icon(
                      Icons.star,
                      color: Color(0xFFFDD000),
                    ),
                    value: selectedLeaderboards['battle'],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedLeaderboards['battle'] = value ?? false;
                        selectAll =
                            selectedLeaderboards['challenge']! &&
                                selectedLeaderboards['battle']!;
                      });
                    },
                    activeColor: const Color(0xFF046EB8),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Export Format',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _performExportFromDialog(selectedLeaderboards, 'CSV', context),
                          icon: const Icon(Icons.table_chart, size: 18),
                          label: const Text('CSV', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF046EB8),
                            side: const BorderSide(color: Color(0xFF046EB8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _performExportFromDialog(selectedLeaderboards, 'Excel', context),
                          icon: const Icon(Icons.grid_on, size: 18),
                          label: const Text('Excel', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF046EB8),
                            side: const BorderSide(color: Color(0xFF046EB8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _performExportFromDialog(selectedLeaderboards, 'PDF', context),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('PDF', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF046EB8),
                            side: const BorderSide(color: Color(0xFF046EB8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: Color(0xFF046EB8),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF046EB8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _performExportFromDialog(
      Map<String, bool> selectedLeaderboards,
      String format,
      BuildContext dialogContext,
      ) {
    if (!selectedLeaderboards['challenge']! &&
        !selectedLeaderboards['battle']!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select at least one leaderboard',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Close ONLY the dialog using its own context
    Navigator.of(dialogContext).pop();

    String leaderboardType;
    if (selectedLeaderboards['challenge']! && selectedLeaderboards['battle']!) {
      leaderboardType = 'both';
    } else if (selectedLeaderboards['challenge']!) {
      leaderboardType = 'challenge';
    } else {
      leaderboardType = 'battle';
    }

    _performExport(format, leaderboardType);
  }

  void _selectExportFormat(String leaderboardType) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Export Format',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Exporting ${_getLeaderboardLabel(leaderboardType)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.file_upload_outlined,
                      color: Color(0xFF046EB8),
                    ),
                    title: const Text(
                      'Export as CSV',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                    ),
                    onTap: () {
                      _performExport('CSV', leaderboardType);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_upload_outlined,
                      color: Color(0xFF046EB8),
                    ),
                    title: const Text(
                      'Export as Excel',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                    ),
                    onTap: () {
                      _performExport('Excel', leaderboardType);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_upload_outlined,
                      color: Color(0xFF046EB8),
                    ),
                    title: const Text(
                      'Export as PDF',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                    ),
                    onTap: () {
                      _performExport('PDF', leaderboardType);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF046EB8),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF046EB8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLeaderboardLabel(String type) {
    switch (type) {
      case 'challenge':
        return 'Badges';
      case 'battle':
        return 'Stars';
      case 'both':
        return 'Both Leaderboards';
      default:
        return '';
    }
  }

  void _performExport(String format, String leaderboardType) {
    // No Navigator.pop here — dialog is already closed by _performExportFromDialog
    switch (format) {
      case 'CSV':
        _downloadCSV(leaderboardType);
        break;
      case 'Excel':
        _downloadExcel(leaderboardType);
        break;
      case 'PDF':
        _downloadPDF(leaderboardType);
        break;
    }
  }

  // ─── Browser download trigger (same pattern as admin_dashboard.dart) ────────
  void _triggerBrowserDownload(Uint8List bytes, String filename, String mimeType) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..setAttribute('download', filename);
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: const Color(0xFF27AE60),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── CSV Download ─────────────────────────────────────────────────────────
  void _downloadCSV(String leaderboardType) {
    final buffer = StringBuffer();
    buffer.writeln('"Starbooks Whiz Challenge - Leaderboard Export"');
    buffer.writeln('"Generated","${DateTime.now().toString().substring(0, 19)}"');
    buffer.writeln();

    if (leaderboardType == 'challenge' || leaderboardType == 'both') {
      buffer.writeln('"=== BADGES LEADERBOARD ==="');
      buffer.writeln('"Rank","Username","Total Badges","Easy","Average","Difficult","Last Claim"');
      for (int i = 0; i < challengeData.length; i++) {
        final p = challengeData[i];
        buffer.writeln(
          '"${i + 1}","${p['username']}","${p['totalRewards']}",'
              '"${p['easy']}","${p['avg']}","${p['diff']}",'
              '"${p['last']}"',
        );
      }
      buffer.writeln();
    }

    if (leaderboardType == 'battle' || leaderboardType == 'both') {
      buffer.writeln('"=== STARS LEADERBOARD ==="');
      buffer.writeln('"Rank","Username","Total Stars","Last Updated","Status"');
      for (int i = 0; i < battleData.length; i++) {
        final p = battleData[i];
        buffer.writeln(
          '"${i + 1}","${p['username']}","${p['rewards']}",'
              '"${p['last']}","${p['status']}"',
        );
      }
      buffer.writeln();
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    _triggerBrowserDownload(
      bytes,
      'starbooks_leaderboard_${DateTime.now().millisecondsSinceEpoch}.csv',
      'text/csv',
    );
    _showSuccessSnackBar('Leaderboard exported as CSV!');
  }

  // ─── Excel Download (XLSX via XML SpreadsheetML) ──────────────────────────
  void _downloadExcel(String leaderboardType) {
    // Build a proper XLSX using SpreadsheetML XML format
    final rows = StringBuffer();

    void addHeaderRow(List<String> cols) {
      rows.write('<Row ss:StyleID="header">');
      for (final c in cols) {
        rows.write('<Cell><Data ss:Type="String">$c</Data></Cell>');
      }
      rows.write('</Row>');
    }

    void addDataRow(List<String> cols) {
      rows.write('<Row>');
      for (final c in cols) {
        rows.write('<Cell><Data ss:Type="String">$c</Data></Cell>');
      }
      rows.write('</Row>');
    }

    void addSectionTitle(String title) {
      rows.write(
        '<Row><Cell ss:StyleID="section"><Data ss:Type="String">$title</Data></Cell></Row>',
      );
    }

    void addBlankRow() {
      rows.write('<Row><Cell><Data ss:Type="String"></Data></Cell></Row>');
    }

    if (leaderboardType == 'challenge' || leaderboardType == 'both') {
      addSectionTitle('BADGES LEADERBOARD');
      addHeaderRow(['Rank', 'Username', 'Total Badges', 'Easy', 'Average', 'Difficult', 'Last Claim']);
      for (int i = 0; i < challengeData.length; i++) {
        final p = challengeData[i];
        addDataRow([
          '${i + 1}', '${p['username']}', '${p['totalRewards']}',
          '${p['easy']}', '${p['avg']}', '${p['diff']}',
          '${p['last']}',
        ]);
      }
      addBlankRow();
    }

    if (leaderboardType == 'battle' || leaderboardType == 'both') {
      addSectionTitle('STARS LEADERBOARD');
      addHeaderRow(['Rank', 'Username', 'Total Stars', 'Last Updated', 'Status']);
      for (int i = 0; i < battleData.length; i++) {
        final p = battleData[i];
        addDataRow([
          '${i + 1}', '${p['username']}', '${p['rewards']}',
          '${p['last']}', '${p['status']}',
        ]);
      }
    }

    final xml = '''<?xml version="1.0"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
 <Styles>
  <Style ss:ID="header">
   <Font ss:Bold="1" ss:Color="#FFFFFF"/>
   <Interior ss:Color="#046EB8" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="section">
   <Font ss:Bold="1" ss:Color="#046EB8"/>
  </Style>
 </Styles>
 <Worksheet ss:Name="Leaderboard">
  <Table>$rows</Table>
 </Worksheet>
</Workbook>''';

    final bytes = Uint8List.fromList(utf8.encode(xml));
    _triggerBrowserDownload(
      bytes,
      'starbooks_leaderboard_${DateTime.now().millisecondsSinceEpoch}.xls',
      'application/vnd.ms-excel',
    );
    _showSuccessSnackBar('Leaderboard exported as Excel!');
  }

  // ─── PDF Download ─────────────────────────────────────────────────────────
  Future<void> _downloadPDF(String leaderboardType) async {
    PdfColor hexToPdf(int hex) => PdfColor(
      ((hex >> 16) & 0xFF) / 255,
      ((hex >> 8) & 0xFF) / 255,
      (hex & 0xFF) / 255,
    );

    final primaryColor = hexToPdf(0xFF046EB8);
    final pdf = pw.Document();

    // Build table rows helper
    pw.Widget buildTable({
      required List<String> headers,
      required List<List<String>> rows,
      required String title,
    }) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          // Table header row
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {for (int i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth()},
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: hexToPdf(0xFFE8F4FD)),
                children: headers.map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                )).toList(),
              ),
              ...rows.asMap().entries.map((entry) {
                final isEven = entry.key % 2 == 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : hexToPdf(0xFFF8FBFF),
                  ),
                  children: entry.value.map((cell) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                  )).toList(),
                );
              }),
            ],
          ),
        ],
      );
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        // Report header
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Starbooks Whiz Challenge',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
              pw.Text(
                'Leaderboard Report',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated: ${DateTime.now().toString().substring(0, 19)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
        pw.SizedBox(height: 20),

        // Badges table
        if (leaderboardType == 'challenge' || leaderboardType == 'both') ...[
          buildTable(
            title: 'BADGES LEADERBOARD',
            headers: ['Rank', 'Username', 'Total Badges', 'Easy', 'Avg', 'Difficult', 'Last Claim'],
            rows: challengeData.asMap().entries.map((e) => [
              '${e.key + 1}',
              '${e.value['username']}',
              '${e.value['totalRewards']}',
              '${e.value['easy']}',
              '${e.value['avg']}',
              '${e.value['diff']}',
              '${e.value['last']}',
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
        ],

        // Stars table
        if (leaderboardType == 'battle' || leaderboardType == 'both')
          buildTable(
            title: 'STARS LEADERBOARD',
            headers: ['Rank', 'Username', 'Stars', 'Last Updated', 'Status'],
            rows: battleData.asMap().entries.map((e) => [
              '${e.key + 1}',
              '${e.value['username']}',
              '${e.value['rewards']}',
              '${e.value['last']}',
              '${e.value['status']}',
            ]).toList(),
          ),
      ],
    ));

    final pdfBytes = await pdf.save();
    _triggerBrowserDownload(
      pdfBytes,
      'starbooks_leaderboard_${DateTime.now().millisecondsSinceEpoch}.pdf',
      'application/pdf',
    );
    _showSuccessSnackBar('Leaderboard exported as PDF!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF94D2FD),
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top controls with buttons on opposite sides
            LayoutBuilder(builder: (context, topConstraints) {
              final isNarrow = topConstraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          _buildModeButton("Badges", "challenge"),
                          const SizedBox(width: 8),
                          _buildModeButton("Stars", "battle"),
                        ]),
                        Row(children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: TextButton.icon(
                              onPressed: _exportData,
                              icon: const Icon(Icons.upload_outlined, size: 16, color: Colors.black87),
                              label: const Text('Export', style: TextStyle(color: Colors.black87, fontSize: 13, fontFamily: 'Poppins')),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _refreshData,
                            icon: const Icon(Icons.refresh, size: 20),
                            style: IconButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: const CircleBorder()),
                            tooltip: 'Refresh',
                          ),
                        ]),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Mode buttons
                  Row(
                    children: [
                      _buildModeButton("Badges", "challenge"),
                      const SizedBox(width: 12),
                      _buildModeButton("Stars", "battle"),
                    ],
                  ),
                  // Right side - Action buttons
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextButton.icon(
                          onPressed: _exportData,
                          icon: const Icon(Icons.upload_outlined, size: 16, color: Colors.black87),
                          label: const Text('Export', style: TextStyle(color: Colors.black87, fontSize: 13, fontFamily: 'Poppins')),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh, size: 20),
                        style: IconButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: const CircleBorder(),
                        ),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),

            // Table
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700;
                Widget tableContent = Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                      child: selectedMode == "challenge"
                          ? Row(
                        children: const [
                          SizedBox(width: 50),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Username",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Total Badges",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Easy",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                color: Color(0xFF27AE60),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Average",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Difficult",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                color: Color(0xFFE74C3C),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Last Claim",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      )
                          : Row(
                        children: const [
                          SizedBox(width: 50),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Username",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Total Stars",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Last Updated",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Rows
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade300),
                            right: BorderSide(color: Colors.grey.shade300),
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                        child: ListView.builder(
                          itemCount: leaderboardData.length,
                          itemBuilder: (context, index) {
                            final player = leaderboardData[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: index % 2 == 0
                                    ? Colors.white
                                    : Colors.grey.shade50,
                                border: Border(
                                  bottom: index < leaderboardData.length - 1
                                      ? BorderSide(color: Colors.grey.shade300)
                                      : BorderSide.none,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              child: selectedMode == "challenge"
                                  ? _buildChallengeRow(player, index)
                                  : _buildBattleRow(player, index),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
                if (isMobile) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: 680, child: tableContent),
                  );
                }
                return tableContent;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeRow(Map<String, dynamic> player, int index) {
    return Row(
      children: [
        _buildRankBadge(index + 1),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF046EB8), width: 2),
                  color: Colors.grey.shade200,
                ),
                child: ClipOval(
                  child: Image.asset(
                    player["avatar"],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.person, color: Color(0xFF046EB8));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                player["username"],
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            "${player["totalRewards"]}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            "${player["easy"]}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            "${player["avg"]}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            "${player["diff"]}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildDateTimeCell(player["last"]),
        ),
      ],
    );
  }

  Widget _buildBattleRow(Map<String, dynamic> player, int index) {
    return Row(
      children: [
        _buildRankBadge(index + 1),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF046EB8), width: 2),
                  color: Colors.grey.shade200,
                ),
                child: ClipOval(
                  child: Image.asset(
                    player["avatar"],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.person, color: Color(0xFF046EB8));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                player["username"],
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Color(0xFFFDD000), size: 18),
              const SizedBox(width: 4),
              Text(
                "${player["rewards"]}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildDateTimeCell(player["last"]),
        ),
      ],
    );
  }

  Widget _buildModeButton(String label, String mode) {
    final bool isSelected = selectedMode == mode;
    return ElevatedButton(
      onPressed: () => setState(() => selectedMode = mode),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF046EB8) : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: isSelected ? const Color(0xFF046EB8) : Colors.grey.shade400,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon,
      String? label,
      VoidCallback onPressed,
      ) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.all(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "May 23, 2025" — divider — "15:45"  (input: "MM/DD/YYYY HH:MM")
  Widget _buildDateTimeCell(String dateTimeStr) {
    String datePart = dateTimeStr;
    String timePart = '';
    final spaceIdx = dateTimeStr.indexOf(' ');
    if (spaceIdx != -1) {
      datePart = dateTimeStr.substring(0, spaceIdx);
      timePart = dateTimeStr.substring(spaceIdx + 1);
    }
    String formattedDate = datePart;
    final pieces = datePart.split('/');
    if (pieces.length == 3) {
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final m = int.tryParse(pieces[0]) ?? 0;
      final d = int.tryParse(pieces[1]) ?? 0;
      final y = pieces[2];
      if (m >= 1 && m <= 12) formattedDate = '${months[m]} $d, $y';
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formattedDate,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
          if (timePart.isNotEmpty) ...[
            const SizedBox(height: 3),
            Container(width: 56, height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 3),
            Text(
              timePart,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color bgColor;
    switch (rank) {
      case 1:
        bgColor = const Color(0xFFFFD700); // Gold
        break;
      case 2:
        bgColor = const Color(0xFFC0C0C0); // Silver
        break;
      case 3:
        bgColor = const Color(0xFFCD7F32); // Bronze
        break;
      default:
        bgColor = const Color(0xFF34495E);
    }

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        "$rank",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}