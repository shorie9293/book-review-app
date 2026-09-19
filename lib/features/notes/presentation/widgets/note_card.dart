import 'package:flutter/material.dart';
import 'package:book_review_app/domain/models/book_note.dart';

/// 読書メモ・引用のカードウィジェット。
///
/// 種別バッジ、ページ番号、本文、タグ、日付、編集/削除ボタンを表示する。
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    this.onToggleFavorite,
  });

  final BookNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// お気に入り切替コールバック（未指定なら星ボタンを表示しない）
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('note_card'),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  key: const Key('note_card_kind_badge'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: note.isQuote
                        ? Colors.indigo.shade50
                        : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note.kind.label,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  note.pageLabel,
                  key: const Key('note_card_page'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              note.content,
              key: const Key('note_card_content'),
              style: const TextStyle(fontSize: 16),
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                key: const Key('note_card_tags'),
                spacing: 6,
                children: [
                  for (final tag in note.tags)
                    Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${note.createdAt.year}/${note.createdAt.month}/${note.createdAt.day}',
              key: const Key('note_card_date'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onToggleFavorite != null)
                  IconButton(
                    key: const Key('note_card_favorite_button'),
                    icon: Icon(
                      note.isFavorite ? Icons.star : Icons.star_border,
                      color: note.isFavorite ? Colors.amber : null,
                    ),
                    tooltip: 'お気に入り',
                    onPressed: onToggleFavorite,
                  ),
                IconButton(
                  key: const Key('note_card_edit_button'),
                  icon: const Icon(Icons.edit),
                  tooltip: '編集',
                  onPressed: onEdit,
                ),
                IconButton(
                  key: const Key('note_card_delete_button'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '削除',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
