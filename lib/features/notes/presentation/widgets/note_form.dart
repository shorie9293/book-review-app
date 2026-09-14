import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:book_review_app/domain/models/book_note.dart';

/// 読書メモ・引用の入力フォーム。
///
/// 新規作成または既存メモの編集に使用する。
/// 入力の検証（本文必須・ページ番号は1以上）を行い、妥当なときのみ
/// [onSave] を呼ぶ。
class NoteForm extends StatefulWidget {
  final String bookId;
  final BookNote? note;
  final ValueChanged<BookNote> onSave;
  final VoidCallback onCancel;

  const NoteForm({
    super.key,
    required this.bookId,
    required this.onSave,
    required this.onCancel,
    this.note,
  });

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  late NoteKind _kind;
  late final TextEditingController _contentController;
  late final TextEditingController _pageController;
  late final TextEditingController _tagController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _kind = note?.kind ?? NoteKind.memo;
    _contentController = TextEditingController(text: note?.content ?? '');
    _pageController =
        TextEditingController(text: note?.pageNumber?.toString() ?? '');
    _tagController = TextEditingController(text: note?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    _pageController.dispose();
    _tagController.dispose();
    super.dispose();
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
                onSelected: (_) => setState(() => _kind = NoteKind.memo),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const Key('note_form_kind_quote'),
                label: const Text('引用'),
                selected: _kind == NoteKind.quote,
                onSelected: (_) => setState(() => _kind = NoteKind.quote),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('note_form_content'),
            controller: _contentController,
            maxLines: 4,
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
            decoration: const InputDecoration(
              labelText: 'ページ番号（任意）',
              hintText: '12',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('note_form_tags'),
            controller: _tagController,
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
