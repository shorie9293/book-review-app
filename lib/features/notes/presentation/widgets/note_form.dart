import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:book_review_app/core/input/draft_store.dart';
import 'package:book_review_app/core/input/unsaved_changes.dart';
import 'package:book_review_app/domain/models/book_note.dart';

/// 読書メモ・引用の入力フォーム。
///
/// 新規作成または既存メモの編集に使用する。
/// 入力の検証（本文必須・ページ番号は1以上）を行い、妥当なときのみ
/// [onSave] を呼ぶ。
///
/// [draftStore] と [draftKey] を渡すと、入力途中の本文・ページ・タグを
/// 下書きとして保存し、開き直したときに復元する
/// （保存成功後の削除は呼び出し側の責務）。
class NoteForm extends StatefulWidget {
  final String bookId;
  final BookNote? note;
  final ValueChanged<BookNote> onSave;
  final VoidCallback onCancel;

  /// 下書きの保存先（null なら下書き機能なし）。
  final DraftStore? draftStore;

  /// 下書きのキー（[draftStore] 指定時のみ使う）。
  final String? draftKey;

  const NoteForm({
    super.key,
    required this.bookId,
    required this.onSave,
    required this.onCancel,
    this.note,
    this.draftStore,
    this.draftKey,
  });

  @override
  State<NoteForm> createState() => NoteFormState();
}

/// フォームの状態（破棄確認のため、未保存の変更を外から問い合わせられる）。
class NoteFormState extends State<NoteForm> {
  late NoteKind _kind;
  late final TextEditingController _contentController;
  late final TextEditingController _pageController;
  late final TextEditingController _tagController;
  String? _errorMessage;

  /// 開いた時点の値（破棄判定の基準）。
  late final NoteKind _initialKind;
  late final String _initialContent;
  late final String _initialPage;
  late final String _initialTags;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _initialKind = note?.kind ?? NoteKind.memo;
    _initialContent = note?.content ?? '';
    _initialPage = note?.pageNumber?.toString() ?? '';
    _initialTags = note?.tags.join(', ') ?? '';

    _kind = _initialKind;
    _contentController = TextEditingController(text: _initialContent);
    _pageController = TextEditingController(text: _initialPage);
    _tagController = TextEditingController(text: _initialTags);
    _restoreDraft();
  }

  /// 未保存の変更があるか（空白差のみは未変更）。
  bool get isDirty =>
      _kind != _initialKind ||
      UnsavedChangesGuard.isAnyDirty(
        {
          'content': _initialContent,
          'page': _initialPage,
          'tags': _initialTags,
        },
        {
          'content': _contentController.text,
          'page': _pageController.text,
          'tags': _tagController.text,
        },
      );

  @override
  void dispose() {
    _contentController.dispose();
    _pageController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String _encodeDraft() => json.encode({
        'kind': _kind.name,
        'content': _contentController.text,
        'page': _pageController.text,
        'tags': _tagController.text,
      });

  /// 下書きを復元する（本文が空のときだけ・破損は無視）。
  Future<void> _restoreDraft() async {
    final store = widget.draftStore;
    final key = widget.draftKey;
    if (store == null || key == null) return;

    final raw = await store.read(key);
    if (raw == null || !mounted) return;

    final decoded = decodeDraftJson(raw);
    // 旧形式（本文のみを保存した下書き）にも耐える。
    final content = decoded?['content'] as String? ?? raw;
    if (content.trim().isEmpty) return;

    setState(() {
      _contentController.text = content;
      final page = decoded?['page'];
      if (page is String) _pageController.text = page;
      final tags = decoded?['tags'];
      if (tags is String) _tagController.text = tags;
      final kind = decoded?['kind'];
      if (kind == NoteKind.quote.name) {
        _kind = NoteKind.quote;
      } else if (kind == NoteKind.memo.name) {
        _kind = NoteKind.memo;
      }
    });
  }

  /// 入力のたびに下書きを書く（空になったら消す）。
  void _persistDraft() {
    final store = widget.draftStore;
    final key = widget.draftKey;
    if (store == null || key == null) return;
    unawaited(store.write(key, _encodeDraft()));
  }

  /// ページ番号入力を解釈する（空欄は null、不正は FormatException）
  int? _parsePage() {
    final raw = _pageController.text.trim();
    if (raw.isEmpty) return null;
    final value = int.tryParse(raw);
    if (value == null || value < 1) {
      throw const FormatException('ページ番号は1以上の整数で入力してください');
    }
    return value;
  }

  /// タグ入力を解釈する（カンマ・読点区切り、空要素は除外）
  List<String> _parseTags() {
    return _tagController.text
        .split(RegExp(r'[,、]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  void _onSave() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _errorMessage = 'メモ本文を入力してください';
      });
      return;
    }

    final int? pageNumber;
    try {
      pageNumber = _parsePage();
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      return;
    }

    final now = DateTime.now();
    final existing = widget.note;
    final note = BookNote(
      id: existing?.id ?? const Uuid().v4(),
      bookId: widget.bookId,
      kind: _kind,
      content: content,
      pageNumber: pageNumber,
      tags: _parseTags(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    widget.onSave(note);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChoiceChip(
                key: const Key('note_form_kind_memo'),
                label: const Text('メモ'),
                selected: _kind == NoteKind.memo,
                onSelected: (_) {
                  setState(() => _kind = NoteKind.memo);
                  _persistDraft();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const Key('note_form_kind_quote'),
                label: const Text('引用'),
                selected: _kind == NoteKind.quote,
                onSelected: (_) {
                  setState(() => _kind = NoteKind.quote);
                  _persistDraft();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('note_form_content'),
            controller: _contentController,
            maxLines: 4,
            onChanged: (_) => _persistDraft(),
            decoration: const InputDecoration(
              labelText: '本文',
              hintText: '気づきや引用を書き残す',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('note_form_page'),
            controller: _pageController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => _persistDraft(),
            decoration: const InputDecoration(
              labelText: 'ページ番号（任意）',
              hintText: '12',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('note_form_tags'),
            controller: _tagController,
            onChanged: (_) => _persistDraft(),
            decoration: const InputDecoration(
              labelText: 'タグ（任意・カンマ区切り）',
              hintText: '学び, 実践',
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              key: const Key('note_form_error'),
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('note_form_cancel'),
                onPressed: widget.onCancel,
                child: const Text('キャンセル'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('note_form_save'),
                onPressed: _onSave,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
