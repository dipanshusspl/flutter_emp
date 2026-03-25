import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/employee.dart';
 
class PayslipScreen extends StatelessWidget {
  final Employee employee;
  const PayslipScreen({super.key, required this.employee});
 
  // ── All salary calculations ──
  Map<String, double> _calc() {
    // CTC is annual. Convert to monthly first.
    final monthly = employee.ctc / 12;
 
    // Basic is the base. We back-calculate:
    // CTC = basic + all_allowances + employer_pf
    // Allowances = 4 * 10% of basic = 40% of basic
    // Employer PF = 12% of basic
    // So CTC = basic * (1 + 0.40 + 0.12) = basic * 1.52
    final basic = monthly / 1.52;
 
    final hra      = basic * 0.10;
    final medical  = basic * 0.10;
    final mobile   = basic * 0.10;
    final washing  = basic * 0.10;
    final ca       = basic * 0.10;  // fixed conveyance allowance
    final bonus    = basic * 0.05;
    final cca      = basic * 0.05;   // fixed CCA
 
    final totalAllowance = hra + medical + mobile + washing + ca + bonus + cca;
    final grossSalary = basic + totalAllowance;
 
    // Deductions
    final pf       = basic * 0.12;
    final esic     = basic * 0.10;
    final pt       = 200.0;
    final tds      = 0.0;
    final loan     = 0.0;
    final advance  = 0.0;
 
    final totalDed = pf + esic + pt + tds + loan + advance;
    final netSalary = grossSalary - totalDed;
 
    return {
      'basic'   : basic,
      'hra'     : hra,
      'medical' : medical,
      'mobile'  : mobile,
      'washing' : washing,
      'ca'      : ca,
      'bonus'   : bonus,
      'cca'     : cca,
      'gross'   : grossSalary,
      'pf'      : pf,
      'esic'    : esic,
      'pt'      : pt,
      'tds'     : tds,
      'loan'    : loan,
      'advance' : advance,
      'totalDed': totalDed,
      'net'     : netSalary,
      'monthly' : monthly,
    };
  }
 
  // ── Generate and show PDF ──
  Future<void> _showPdf(BuildContext ctx, Map<String, double> s) async {
    final pdf = pw.Document();
 
    pw.TableRow row(String label, double entitled, double earned) {
      return pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(4),
          child: pw.Text(label)),
        pw.Padding(padding: const pw.EdgeInsets.all(4),
          child: pw.Text('₹${entitled.toStringAsFixed(0)}',
            textAlign: pw.TextAlign.right)),
        pw.Padding(padding: const pw.EdgeInsets.all(4),
          child: pw.Text('₹${earned.toStringAsFixed(0)}',
            textAlign: pw.TextAlign.right)),
      ]);
    }
 
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PAYSLIP', style: pw.TextStyle(
            fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Employee: ${employee.name}'),
          pw.Text('Monthly CTC: ₹${s['monthly']!.toStringAsFixed(0)}'),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              // Header
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Description',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Entitled',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Earned',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ]),
              row('Basic',              s['basic']!,   s['basic']!),
              row('HRA',                s['hra']!,     s['hra']!),
              row('Medical Allowance',  s['medical']!, s['medical']!),
              row('Mobile & Internet',  s['mobile']!,  s['mobile']!),
              row('Washing Allowance',  s['washing']!, s['washing']!),
              row('CA',                 s['ca']!,      s['ca']!),
              row('Bonus',              s['bonus']!,   s['bonus']!),
              row('CCA',                s['cca']!,     s['cca']!),
              // Deductions
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('--- DEDUCTIONS ---',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red))),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('')),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('')),
              ]),
              row('PF (12%)',       s['pf']!,      s['pf']!),
              row('ESIC (10%)',     s['esic']!,    s['esic']!),
              row('PT',            s['pt']!,      s['pt']!),
              row('TDS',           s['tds']!,     s['tds']!),
              row('Loan',          s['loan']!,    s['loan']!),
              row('Advance Salary',s['advance']!, s['advance']!),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total Deductions : ₹${s['totalDed']!.toStringAsFixed(0)}'),
          pw.Text('Net Salary        : ₹${s['net']!.toStringAsFixed(0)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ));
 
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
  }
 
  Widget _row(String label, double amt, {bool bold = false}) {
    final style = bold
      ? const TextStyle(fontWeight: FontWeight.bold)
      : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text('₹${amt.toStringAsFixed(0)}', style: style),
      ]),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final s = _calc();
    return Scaffold(
      appBar: AppBar(
        title: Text('Payslip — ${employee.name}'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => _showPdf(context, s),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(employee.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Monthly CTC: ₹${s['monthly']!.toStringAsFixed(0)}'),
              ]),
            )),
            const SizedBox(height: 12),
 
            // Allowances
            const Text('ALLOWANCES',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            Card(child: Column(children: [
              _row('Basic',             s['basic']!),
              _row('Bonus',             s['bonus']!),
              _row('CA',                s['ca']!),
              _row('HRA (10%)',         s['hra']!),
              _row('Medical (10%)',     s['medical']!),
              _row('Mobile (10%)',      s['mobile']!),
              _row('Washing (10%)',     s['washing']!),
              _row('CCA',              s['cca']!),
              const Divider(),
              _row('Gross Salary', s['gross']!, bold: true),
            ])),
            const SizedBox(height: 12),
 
            // Deductions
            const Text('DEDUCTIONS',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            Card(child: Column(children: [
              _row('PF (12%)',       s['pf']!),
              _row('ESIC (10%)',     s['esic']!),
              _row('PT',            s['pt']!),
              _row('TDS',           s['tds']!),
              _row('Loan',          s['loan']!),
              _row('Advance Salary',s['advance']!),
              const Divider(),
              _row('Total Deductions', s['totalDed']!, bold: true),
            ])),
            const SizedBox(height: 12),
 
            // Net
            Card(
              color: Colors.green.shade50,
              child: _row('NET SALARY', s['net']!, bold: true),
            ),
          ],
        ),
      ),
    );
  }
}
