import 'package:flutter/material.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/data/loan_due_reminder_repository.dart';
import 'package:book_review_app/features/loan/domain/book_loan_service.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_coordinator.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_service.dart';
import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_scheduler.dart';
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

  /// 返却期限リマインダー設定の永続化先。
  /// [reminderScheduler] と両方指定したときのみ通知設定を描画する。
  final LoanDueReminderRepository? reminderRepository;

  /// 返却期限リマインダーの通知スケジューラ。
  final LoanDueReminderScheduler? reminderScheduler;

  const LoanManagementScreen({
    super.key,
    required this.repository,
    this.nowOverride,
    this.bookTitleLoader,
    this.reminderRepository,
    this.reminderScheduler,
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

  LoanDueReminderSettings? _reminderSettings;
  LoanDueReminderPlan? _reminderPlan;
  int? _selectedHour;
  bool _reminderSaving = false;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  /// 通知設定セクションを描画してよいか（両依存が揃っているときのみ）。
  bool get _reminderEnabled =>
      widget.reminderRepository != null && widget.reminderScheduler != null;

  @override
  void initState() {
    super.initState();
    _load();
    if (_reminderEnabled) _loadReminderSettings();
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
    // 対象件数が変わるため通知本文を作り直す（失敗しても画面は壊さない）。
    if (_reminderEnabled) await _rescheduleReminder();
  }

  /// 保存済みの通知設定を読み込み、通知の登録状態も同期する。
  Future<void> _loadReminderSettings() async {
    final repo = widget.reminderRepository;
    if (repo == null) return;
    LoanDueReminderSettings settings;
    try {
      settings = await repo.load();
    } catch (_) {
      settings = LoanDueReminderSettings.defaults();
    }
    if (!mounted) return;
    setState(() {
      _reminderSettings = settings;
      _selectedHour = settings.hour;
    });
    await _rescheduleReminder();
  }

  /// 調整役に登録/解除を委ね、プレビュー用の計画を更新する。
  Future<void> _rescheduleReminder() async {
    final repo = widget.reminderRepository;
    final scheduler = widget.reminderScheduler;
    if (repo == null || scheduler == null) return;
    try {
      final coordinator = LoanDueReminderCoordinator(
        settingsRepository: repo,
        loanRepository: widget.repository,
        scheduler: scheduler,
        clock: () => _now,
        bookTitleLoader: widget.bookTitleLoader,
      );
      final plan = await coordinator.reschedule();
      if (!mounted) return;
      setState(() => _reminderPlan = plan);
    } catch (_) {
      // 通知系の失敗で貸出管理の操作を止めない。
    }
  }

  /// ON/OFF を即座に永続化し、通知を再調整する。
  Future<void> _onReminderEnabledChanged(bool value) async {
    final repo = widget.reminderRepository;
    final current = _reminderSettings;
    if (repo == null || current == null) return;
    final updated = current.copyWith(
      enabled: value,
      hour: _selectedHour ?? current.hour,
      updatedAt: _now,
    );
    setState(() {
      _reminderSettings = updated;
      _reminderSaving = true;
    });
    try {
      await repo.save(updated);
    } catch (_) {
      // 保存失敗でも UI は落とさない（次回保存で再試行される）。
    }
    await _rescheduleReminder();
    if (!mounted) return;
    setState(() => _reminderSaving = false);
  }

  /// 時刻（時）を永続化し、通知を再調整する。
  Future<void> _saveReminderSettings() async {
    final repo = widget.reminderRepository;
    final current = _reminderSettings;
    if (repo == null || current == null) return;
    final updated = current.copyWith(
      hour: _selectedHour ?? current.hour,
      minute: 0,
      updatedAt: _now,
    );
    setState(() {
      _reminderSettings = updated;
      _reminderSaving = true;
    });
    try {
      await repo.save(updated);
    } catch (_) {
      // 同上。
    }
    await _rescheduleReminder();
    if (!mounted) return;
    setState(() => _reminderSaving = false);
  }

  String get _reminderStatusLabel {
    final plan = _reminderPlan;
    if (plan == null) return '通知の状態を確認中…';
    if (plan.isEmpty) return '対象なし';
    return '本日から通知: ${plan.count}件';
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
        if (_reminderEnabled && _reminderSettings != null)
          _buildReminderSection(),
      ],
    );
  }

  /// 返却期限の通知設定セクション（両依存が注入されたときのみ）。
  Widget _buildReminderSection() {
    final settings = _reminderSettings!;
    final hour = _selectedHour ?? settings.hour;
    return Card(
      key: AppKeys.loanDueReminderSection,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: AppKeys.loanDueReminderSwitch,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('返却期限の通知'),
              subtitle: const Text('毎日決まった時刻にお知らせする'),
              value: settings.enabled,
              onChanged: _reminderSaving ? null : _onReminderEnabledChanged,
            ),
            Row(
              children: [
                const Text('通知時刻'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  key: AppKeys.loanDueReminderHour,
                  value: hour,
                  items: [
                    for (var h = 0; h < 24; h++)
                      DropdownMenuItem<int>(
                        value: h,
                        child: Text('${h.toString().padLeft(2, '0')}:00'),
                      ),
                  ],
                  onChanged: _reminderSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedHour = value);
                        },
                ),
                const Spacer(),
                SemanticHelper.interactive(
                  testId: 'loan_due_reminder_save_btn',
                  label: '返却期限の通知設定を保存する',
                  child: ElevatedButton(
                    key: AppKeys.loanDueReminderSave,
                    onPressed:
                        _reminderSaving ? null : _saveReminderSettings,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _reminderStatusLabel,
              key: AppKeys.loanDueReminderStatus,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
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
