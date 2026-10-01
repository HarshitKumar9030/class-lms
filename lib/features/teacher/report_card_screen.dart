import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import 'report_card_repository.dart';
import 'staff_repository.dart';

class ReportCardsScreen extends ConsumerWidget {
  const ReportCardsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Report cards',
    onRefresh: () async => ref.invalidate(managedUsersProvider),
    children: [
      Text(
        'Choose a student to view progress and generate a PDF report.',
        style: TextStyle(color: context.palette.secondary),
      ),
      const SectionHeader(title: 'Students'),
      ref
          .watch(managedUsersProvider)
          .when(
            loading: () => const LoadingRows(),
            error: (_, _) => ErrorState(
              message: 'Couldn’t load students.',
              onRetry: () => ref.invalidate(managedUsersProvider),
            ),
            data: (users) {
              final students = users
                  .where((user) => user.role == 'student')
                  .toList();
              if (students.isEmpty) {
                return const CompactEmptyState(
                  title: 'No students yet',
                  message: 'Students appear after sign-up.',
                  icon: Icons.people_outline,
                );
              }
              return Column(
                children: [
                  for (final student in students)
                    AppRow(
                      title: student.name.isEmpty
                          ? student.email
                          : student.name,
                      subtitle: student.email,
                      icon: Icons.assessment_outlined,
                      onTap: () =>
                          context.push('/teacher/reports/${student.id}'),
                    ),
                ],
              );
            },
          ),
    ],
  );
}

class ReportCardScreen extends ConsumerStatefulWidget {
  const ReportCardScreen({super.key, required this.studentId});
  final String studentId;
  @override
  ConsumerState<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends ConsumerState<ReportCardScreen> {
  int days = 90;
  bool exporting = false;

  Future<void> export(ReportCard report) async {
    setState(() => exporting = true);
    try {
      final bytes = await buildReportPdf(report);
      final temp = await getTemporaryDirectory();
      final safeName = report.studentName.trim().isEmpty
          ? 'student'
          : report.studentName.trim().replaceAll(
              RegExp(r'[^a-zA-Z0-9_-]'),
              '_',
            );
      final file = File(
        '${temp.path}/report_card_${safeName}_${DateFormat('yyyyMMdd').format(report.generatedAt)}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          title: 'Report card for ${report.studentName}',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t generate the PDF.')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportCardProvider((widget.studentId, days)));
    return AppPage(
      title: 'Report card',
      onRefresh: () async =>
          ref.invalidate(reportCardProvider((widget.studentId, days))),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 90, label: Text('90 days')),
            ButtonSegment(value: 0, label: Text('All time')),
          ],
          selected: {days},
          onSelectionChanged: (value) => setState(() => days = value.first),
        ),
        const SizedBox(height: 20),
        report.when(
          loading: () => const LoadingRows(count: 3),
          error: (_, _) => ErrorState(
            message: 'Couldn’t generate this report.',
            onRetry: () =>
                ref.invalidate(reportCardProvider((widget.studentId, days))),
          ),
          data: (card) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.studentName.isEmpty
                          ? card.studentEmail
                          : card.studentName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.studentEmail,
                      style: TextStyle(color: context.palette.secondary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Generated ${DateFormat.yMMMd().add_jm().format(card.generatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'At a glance'),
              _MetricRow(
                label: 'Quiz average',
                value: card.quizAverage == null
                    ? 'No scores'
                    : '${card.quizAverage!.toStringAsFixed(0)}%',
                icon: Icons.quiz_outlined,
              ),
              _MetricRow(
                label: 'Assignments submitted',
                value:
                    '${card.submittedAssignments} / ${card.assignedAssignments}',
                icon: Icons.assignment_turned_in_outlined,
              ),
              _MetricRow(
                label: 'On-time submissions',
                value:
                    '${card.onTimeAssignments} / ${card.submittedAssignments}',
                icon: Icons.schedule_outlined,
              ),
              _MetricRow(
                label: 'Resources opened',
                value: '${card.resourcesOpened}',
                icon: Icons.menu_book_outlined,
              ),
              const SectionHeader(title: 'Insights'),
              for (final insight in card.insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppSurface(child: Text(insight)),
                ),
              const SectionHeader(title: 'Quiz results'),
              if (card.quizEntries.isEmpty)
                const CompactEmptyState(
                  title: 'No quiz attempts',
                  message: 'Submitted quizzes will appear here.',
                  icon: Icons.quiz_outlined,
                )
              else
                for (final row in card.quizEntries.reversed)
                  AppRow(
                    title: row.title,
                    subtitle:
                        '${DateFormat.yMMMd().format(row.date)} · ${row.detail}',
                    icon: Icons.check_circle_outline,
                  ),
              const SectionHeader(title: 'Assignments'),
              if (card.assignmentEntries.isEmpty)
                const CompactEmptyState(
                  title: 'No assignments due',
                  message: 'No assignments were due during this period.',
                  icon: Icons.assignment_outlined,
                )
              else
                for (final row in card.assignmentEntries)
                  AppRow(
                    title: row.title,
                    subtitle:
                        '${DateFormat.yMMMd().format(row.date)} · ${row.detail}',
                    icon: Icons.assignment_outlined,
                  ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Generate & share PDF',
                onPressed: () => export(card),
                busy: exporting,
              ),
              const SizedBox(height: 12),
              Text(
                'Based on recorded quiz scores, due assignments and resource opens. This report does not measure attendance or whether a resource was completed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.palette.secondary,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) =>
      AppRow(title: label, subtitle: value, icon: icon);
}

Future<List<int>> buildReportPdf(ReportCard report) async {
  final document = pw.Document();
  final fontData = await rootBundle.load('assets/fonts/NotoSans.ttf');
  final font = pw.Font.ttf(fontData);
  final blue = PdfColor.fromHex('#3578C6');
  final gray = PdfColor.fromHex('#5A6472');
  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 7),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: blue,
      ),
    ),
  );
  pw.Widget line(String left, String right) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(left, style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.Text(
          right,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      margin: const pw.EdgeInsets.all(38),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: blue, width: 1)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CLASS LMS',
              style: pw.TextStyle(
                color: blue,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'STUDENT REPORT CARD',
              style: pw.TextStyle(color: gray, fontSize: 9),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: gray),
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 18),
        pw.Text(
          report.studentName.isEmpty ? report.studentEmail : report.studentName,
          style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          report.studentEmail,
          style: pw.TextStyle(color: gray, fontSize: 10),
        ),
        pw.Text(
          'Generated ${DateFormat.yMMMd().format(report.generatedAt)} | ${report.periodDays == 0 ? 'All time' : 'Last ${report.periodDays} days'}',
          style: pw.TextStyle(color: gray, fontSize: 10),
        ),
        section('Overview'),
        line(
          'Quiz average',
          report.quizAverage == null
              ? 'No scores'
              : '${report.quizAverage!.toStringAsFixed(0)}%',
        ),
        line(
          'Assignments submitted',
          '${report.submittedAssignments} / ${report.assignedAssignments}',
        ),
        line(
          'On-time submissions',
          '${report.onTimeAssignments} / ${report.submittedAssignments}',
        ),
        line('Distinct resources opened', '${report.resourcesOpened}'),
        section('Learning insights'),
        for (final insight in report.insights)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              '• $insight',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        section('Quiz results'),
        if (report.quizEntries.isEmpty)
          pw.Text(
            'No quiz attempts in this period.',
            style: pw.TextStyle(color: gray, fontSize: 10),
          ),
        for (final row in report.quizEntries.reversed)
          line(
            '${DateFormat.yMMMd().format(row.date)}  ${row.title}',
            row.percent == null
                ? 'Review pending'
                : '${row.percent!.toStringAsFixed(0)}%',
          ),
        section('Assignments'),
        if (report.assignmentEntries.isEmpty)
          pw.Text(
            'No assignments due in this period.',
            style: pw.TextStyle(color: gray, fontSize: 10),
          ),
        for (final row in report.assignmentEntries)
          line(
            '${DateFormat.yMMMd().format(row.date)}  ${row.title}',
            row.detail,
          ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Based on recorded scores, submissions and resource opens. Attendance and completion are not tracked.',
          style: pw.TextStyle(color: gray, fontSize: 8),
        ),
      ],
    ),
  );
  return document.save();
}
