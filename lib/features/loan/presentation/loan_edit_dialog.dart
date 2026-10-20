import 'package:flutter/material.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 貸出を記録するダイアログ。
///
/// 借り手名（必須）と返却予定日（任意）を入力し、確定すると
/// [BookLoan] を組み立てて呼出側へ返す。日時の決定論性のため
/// [lentAt] は必ず呼出側から注入する（`DateTime.now()` は読まない）。
class LoanEditDialog extends StatefulWidget {
  /// 貸出対象の蔵書 ID。
  final String bookId;

  /// 貸出日時（呼出側の now）。
  final DateTime lentAt;

  /// 借り手名の初期値。
  final String? initialBorrower;

  /// 返却予定日の初期値。
  final DateTime? initialDueAt;

  const LoanEditDialog({
    super.key,
    required this.bookId,
    required this.lentAt,
    this.initialBorrower,
    this.initialDueAt,
  });

  /// ダイアログを表示し、確定された [BookLoan] を返す（取消は null）。
  static Future<BookLoan?> show(
    BuildContext context, {
    required String bookId,
    required DateTime lentAt,
    String? initialBorrower,
    DateTime? initialDueAt,
  }) {
    return showDialog<BookLoan>(
      context: context,
      builder: (_) => LoanEditDialog(
        bookId: bookId,
        lentAt: lentAt,
        initialBorrower: initialBorrower,
        initialDueAt: initialDueAt,
      ),
    );
  }

  @override
  State<LoanEditDialog> createState() => _LoanEditDialogState();
}

class _LoanEditDialogState extends State<LoanEditDialog> {
  late final TextEditingController _borrowerController =
      TextEditingController(text: widget.initialBorrower ?? '');
  DateTime? _dueAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dueAt = widget.initialDueAt;
  }

  @override
  void dispose() {
    _borrowerController.dispose();
    super.dispose();
  }

  String get _dueLabel {
    final due = _dueAt;
    if (due == null) return '返却予定日を選ぶ';
    final mm = due.month.toString().padLeft(2, '0');
    final dd = due.day.toString().padLeft(2, '0');
    return '返却予定日 ${due.year}/$mm/$dd';
  }

  Future<void> _pickDueDate() async {
    final base = widget.lentAt;
    final initial = _dueAt ?? DateTime(base.year, base.month, base.day + 14);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(base.year - 10),
      lastDate: DateTime(base.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueAt = picked;
    });
  }

  void _submit() {
    final borrower = _borrowerController.text.trim();
    if (borrower.isEmpty) {
      setState(() => _error = '借り手名を入力してください');
      return;
    }
    final loan = BookLoan(
      id: 'loan_${DateTime.now().microsecondsSinceEpoch}',
      bookId: widget.bookId,
      borrower: borrower,
      lentAt: widget.lentAt,
      dueAt: _dueAt,
    );
    Navigator.of(context).pop(loan);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('貸出を記録'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SemanticHelper.textField(
            testId: 'loan_txt_borrower',
            label: '借り手名を入力',
            child: TextField(
              key: AppKeys.loanBorrowerField,
              controller: _borrowerController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '借り手名',
                errorText: _error,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SemanticHelper.interactive(
            testId: 'loan_btn_due',
            label: '返却予定日を選ぶ',
            child: TextButton.icon(
              key: AppKeys.loanDueButton,
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_dueLabel),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        SemanticHelper.interactive(
          testId: 'loan_btn_save',
          label: '貸出を保存',
          child: FilledButton(
            key: AppKeys.loanSaveButton,
            onPressed: _submit,
            child: const Text('確定'),
          ),
        ),
      ],
    );
  }
}
