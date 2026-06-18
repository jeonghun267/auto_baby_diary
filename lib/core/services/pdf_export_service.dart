import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../data/models/child_profile.dart';
import '../../data/models/growth_record.dart';
import '../../data/models/vaccination_record.dart';
import '../../data/models/milestone_record.dart';

class PdfExportService {
  static final _dateFormat = DateFormat('yyyy.MM.dd');

  /// 한글 글리프를 가진 폰트(나눔고딕 TTF)를 로드한다.
  /// 네트워크 실패 등으로 받지 못하면 기본 helvetica로 폴백한다(영문만 정상).
  Future<(pw.Font, pw.Font)> _loadKoreanFonts() async {
    try {
      final regular = await PdfGoogleFonts.nanumGothicRegular();
      final bold = await PdfGoogleFonts.nanumGothicBold();
      return (regular, bold);
    } catch (e) {
      debugPrint('[PdfExport] 한글 폰트 로드 실패, helvetica로 폴백: $e');
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  Future<Uint8List> generateReport({
    required ChildProfile child,
    required List<GrowthRecord> growth,
    required List<VaccinationRecord> vaccinations,
    required List<MilestoneRecord> milestones,
    bool includeGrowth = true,
    bool includeVaccinations = true,
    bool includeMilestones = true,
  }) async {
    final pdf = pw.Document();
    // 한글이 깨지지 않도록 한글 글리프를 가진 TTF 폰트를 임베드한다.
    // (pdf 패키지 기본 helvetica/Pretendard OTF는 한글 렌더링 불가)
    final (font, fontBold) = await _loadKoreanFonts();

    final headerStyle = pw.TextStyle(font: fontBold, fontSize: 20);
    final sectionStyle = pw.TextStyle(font: fontBold, fontSize: 14);
    final bodyStyle = pw.TextStyle(font: font, fontSize: 10);
    final bodyBoldStyle = pw.TextStyle(font: fontBold, fontSize: 10);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(child, headerStyle, bodyStyle),
        build: (context) {
          final widgets = <pw.Widget>[];

          if (includeGrowth && growth.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Text('Growth Records', style: sectionStyle));
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(_buildGrowthTable(growth, bodyStyle, bodyBoldStyle));
          }

          if (includeVaccinations && vaccinations.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Text('Vaccination Records', style: sectionStyle));
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(
                _buildVaccinationTable(vaccinations, bodyStyle, bodyBoldStyle));
          }

          if (includeMilestones && milestones.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Text('Milestone Records', style: sectionStyle));
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(
                _buildMilestoneChecklist(milestones, bodyStyle, bodyBoldStyle));
          }

          if (widgets.isEmpty) {
            widgets.add(pw.SizedBox(height: 40));
            widgets.add(pw.Text('No records selected.', style: bodyStyle));
          }

          return widgets;
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
    ChildProfile child,
    pw.TextStyle headerStyle,
    pw.TextStyle bodyStyle,
  ) {
    final now = DateTime.now();
    final ageMonths = child.ageInMonths;
    final ageYears = ageMonths ~/ 12;
    final remainMonths = ageMonths % 12;
    final ageText =
        ageYears > 0 ? '${ageYears}y ${remainMonths}m' : '${remainMonths}m';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Pediatric Report', style: headerStyle),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Name: ${child.name}', style: bodyStyle),
                pw.Text(
                  'Birth Date: ${_dateFormat.format(child.birthDate)}',
                  style: bodyStyle,
                ),
                pw.Text('Age: $ageText', style: bodyStyle),
                pw.Text('Gender: ${child.gender}', style: bodyStyle),
              ],
            ),
            pw.Text(
              'Generated: ${_dateFormat.format(now)}',
              style: bodyStyle,
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildGrowthTable(
    List<GrowthRecord> records,
    pw.TextStyle bodyStyle,
    pw.TextStyle boldStyle,
  ) {
    return pw.TableHelper.fromTextArray(
      headerStyle: boldStyle,
      cellStyle: bodyStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      headers: ['Date', 'Height (cm)', 'Weight (kg)', 'Head Circ. (cm)'],
      data: records.map((r) {
        return [
          _dateFormat.format(r.recordedAt),
          r.height?.toStringAsFixed(1) ?? '-',
          r.weight?.toStringAsFixed(1) ?? '-',
          r.headCircumference?.toStringAsFixed(1) ?? '-',
        ];
      }).toList(),
    );
  }

  pw.Widget _buildVaccinationTable(
    List<VaccinationRecord> records,
    pw.TextStyle bodyStyle,
    pw.TextStyle boldStyle,
  ) {
    return pw.TableHelper.fromTextArray(
      headerStyle: boldStyle,
      cellStyle: bodyStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      headers: ['Vaccine', 'Dose', 'Completed', 'Hospital'],
      data: records.map((r) {
        return [
          r.name,
          '${r.doseNumber}',
          r.completedAt != null ? _dateFormat.format(r.completedAt!) : '-',
          r.hospital ?? '-',
        ];
      }).toList(),
    );
  }

  pw.Widget _buildMilestoneChecklist(
    List<MilestoneRecord> records,
    pw.TextStyle bodyStyle,
    pw.TextStyle boldStyle,
  ) {
    final achieved = records.where((m) => m.isAchieved).toList();
    final pending = records.where((m) => !m.isAchieved).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (achieved.isNotEmpty) ...[
          pw.Text('Achieved', style: boldStyle),
          pw.SizedBox(height: 4),
          ...achieved.map((m) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Row(
                  children: [
                    pw.Text('[v] ', style: bodyStyle),
                    pw.Expanded(
                      child: pw.Text(
                        '${m.title} - ${_dateFormat.format(m.achievedAt!)}',
                        style: bodyStyle,
                      ),
                    ),
                  ],
                ),
              )),
        ],
        if (pending.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Pending', style: boldStyle),
          pw.SizedBox(height: 4),
          ...pending.map((m) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Row(
                  children: [
                    pw.Text('[ ] ', style: bodyStyle),
                    pw.Expanded(
                      child: pw.Text(
                        '${m.title} (expected: ${m.expectedMonth}m)',
                        style: bodyStyle,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}
