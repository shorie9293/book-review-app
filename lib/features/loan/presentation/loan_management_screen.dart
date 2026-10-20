import 'package:flutter/material.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/domain/book_loan_service.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 貸出管理の絞込。
enum _LoanFilter { all, active, dueSoon, returned }

/// 蔵書の貸出管理画面。
///
/// サマリー・絞込・検索・返却を一画面で扱う。集計は必ず
/// [BookLoanService] に委ね、画面側で独自集計しない。
class LoanManagementScreen extends StatefulWidget {
  /// 貸出の永続化先。
  final BookLoanRepository repository;

  /// 現在日時の注入（試練の決定論化用）。未指定なら実時計。
  final DateTime? nowOverride;

  /// bookId → 書名の解決関数。null なら書名は表示しない。
  final Future<Map<String, String>> Function()? bookTitleLoader;

  const LoanManagementScreen({
    super.key,
    required this.repository,
    this.nowOverride,
    this.bookTitleLoader,
  });

  @override
  State<LoanManagementScreen> createState() => _LoanManagementScreenState();
}

class _LoanManagementScreenState extends State<LoanManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BookLoan> _loans = const [];
  Map<String, String> _titles = const {};
  _LoanFilter _filter = _LoanFilter.all;
  String _query = '';
  bool _loading = true;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loans = await widget.repository.loadLoans();
    var titles = const <String, String>{};
    final loader = widget.bookTitleLoader;
    if (loader != null) {
      try {
        titles = await loader();
      } catch (_) {
        titles = const {};
      }
    }
    if (!mounted) return;
    setState(() {
      _loans = loans;
      _titles = titles;
      _loading = false;
    });
  }

  /// 現在の絞込・検索に合致する貸出（集計は Service に委譲）。
  List<BookLoan> _visibleLoans() {
    final now = _now;
    final List<BookLoan> base;
    switch (_filter) {
      case _LoanFilter.all:
        base = [
          ...BookLoanService.activeLoans(_loans),
          ...BookLoanService.returnedLoans(_loans),
        ];
        break;
      case _LoanFilter.active:
        base = BookLoanService.activeLoans(_loans);
        break;
      case _LoanFilter.dueSoon:
        final ids = <String>{
          for (final loan in BookLoanService.overdueLoans(_loans, now: now))
            loan.id,
          for (final loan in BookLoanService.dueSoonLoans(_loans, now: now))
            loan.id,
        };
        base = BookLoanService.activeLoans(_loans)
            .where((loan) => ids.contains(loan.id))
            .toList();
        break;
      case _LoanFilter.returned:
        base = BookLoanService.returnedLoans(_loans);
        break;
    }
    return BookLoanService.search(base, _query);
  }

  /// 返却を永続化し、再読込して表示を更新する。
  Future<void> _returnLoan(BookLoan loan) async {
    final current = await widget.repository.loadLoans();
    final updated =
        BookLoanService.markReturned(current, loan.id, _now);
    await widget.repository.saveLoans(updated);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.loanManagementScreen,
      appBar: AppBar(title: const Text('貸出管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final visible = _visibleLoans();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCard(),
        _buildFilterChips(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SemanticHelper.textField(
            testId: 'loan_txt_search',
            label: '借り手名で検索',
            child: TextField(
              key: AppKeys.loanSearchField,
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: '借り手名で検索',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Container(
                    key: AppKeys.loanEmpty,
                    padding: const EdgeInsets.all(24),
                    child: const Text('該当する貸出はありません'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: visible.length,
                  itemBuilder: (context, index) =>
                      _buildLoanRow(visible[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return SemanticHelper.container(
      testId: 'loan_sec_summary',
      label: '貸出サマリー',
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.menu_book_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  BookLoanService.summaryLabel(_loans, now: _now),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(
              key: AppKeys.loanFilterAll,
              label: 'すべて',
              value: _LoanFilter.all,
            ),
            const SizedBox(width: 8),
            _filterChip(
              key: AppKeys.loanFilterActive,
              label: '貸出中',
              value: _LoanFilter.active,
            ),
            const SizedBox(width: 8),
            _filterChip(
              key: AppKeys.loanFilterDueSoon,
              label: '返却予定間近',
              value: _LoanFilter.dueSoon,
            ),
            const SizedBox(width: 8),
            _filterChip(
              key: AppKeys.loanFilterReturned,
              label: '履歴',
              value: _LoanFilter.returned,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required Key key,
    required String label,
    required _LoanFilter value,
  }) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildLoanRow(BookLoan loan) {
    final title = _titles[loan.bookId];
    final subtitleParts = <String>[
      if (title != null && title.isNotEmpty) title,
      BookLoanService.dueLabel(loan, now: _now),
    ];
    return Card(
      key: AppKeys.loanRow(loan.id),
      child: ListTile(
        title: Text(loan.borrower),
        subtitle: Text(subtitleParts.join(' ・ ')),
        trailing: loan.isReturned
            ? const Text('返却済')
            : SemanticHelper.interactive(
                testId: 'loan_btn_return_${loan.id}',
                label: '「${loan.borrower}」の貸出を返却済みにする',
                child: TextButton(
                  key: AppKeys.loanReturnButton(loan.id),
                  onPressed: () => _returnLoan(loan),
                  child: const Text('返却'),
                ),
              ),
      ),
    );
  }
}
