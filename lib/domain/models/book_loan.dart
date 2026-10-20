/// 蔵書の貸出1件を表すモデル。
///
/// [lentAt] は貸出日時、[dueAt] は返却期限（未設定可）、
/// [returnedAt] は返却日時（未返却なら null）。
class BookLoan {
  final String id;
  final String bookId;
  final String borrower;
  final DateTime lentAt;
  final DateTime? dueAt;
  final DateTime? returnedAt;

  BookLoan({
    required this.id,
    required this.bookId,
    required this.borrower,
    required this.lentAt,
    this.dueAt,
    this.returnedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'id must not be empty');
    }
    if (bookId.trim().isEmpty) {
      throw ArgumentError.value(bookId, 'bookId', 'bookId must not be empty');
    }
    if (borrower.trim().isEmpty) {
      throw ArgumentError.value(
          borrower, 'borrower', 'borrower must not be empty');
    }
  }

  /// 返却済みかどうか。
  bool get isReturned => returnedAt != null;

  /// 指定フィールドのみ差し替えた新しい貸出を返す。
  ///
  /// [clearDueAt] / [clearReturnedAt] が true の場合は該当項目を null にする。
  BookLoan copyWith({
    String? borrower,
    DateTime? lentAt,
    DateTime? dueAt,
    bool clearDueAt = false,
    DateTime? returnedAt,
    bool clearReturnedAt = false,
  }) {
    return BookLoan(
      id: id,
      bookId: bookId,
      borrower: borrower ?? this.borrower,
      lentAt: lentAt ?? this.lentAt,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      returnedAt: clearReturnedAt ? null : (returnedAt ?? this.returnedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'borrower': borrower,
        'lentAt': lentAt.toIso8601String(),
        'dueAt': dueAt?.toIso8601String(),
        'returnedAt': returnedAt?.toIso8601String(),
      };

  /// JSON マップから復元する。
  ///
  /// 必須キーの欠落・型不一致・日時不正は [FormatException] を投げる
  /// （リポジトリ側で破損エントリを読み飛ばせるようにするため）。
  factory BookLoan.fromJson(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('BookLoan.id is missing');
    }
    final bookId = map['bookId'];
    if (bookId is! String || bookId.trim().isEmpty) {
      throw const FormatException('BookLoan.bookId is missing');
    }
    final borrower = map['borrower'];
    if (borrower is! String || borrower.trim().isEmpty) {
      throw const FormatException('BookLoan.borrower is missing');
    }
    final lentAt = _parseRequiredDate(map['lentAt'], 'lentAt');
    final dueAt = _parseOptionalDate(map['dueAt'], 'dueAt');
    final returnedAt = _parseOptionalDate(map['returnedAt'], 'returnedAt');
    return BookLoan(
      id: id,
      bookId: bookId,
      borrower: borrower,
      lentAt: lentAt,
      dueAt: dueAt,
      returnedAt: returnedAt,
    );
  }

  static DateTime _parseRequiredDate(Object? raw, String key) {
    if (raw is! String) {
      throw FormatException('BookLoan.$key is invalid');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('BookLoan.$key is invalid');
    }
    return parsed;
  }

  static DateTime? _parseOptionalDate(Object? raw, String key) {
    if (raw == null) return null;
    if (raw is! String) {
      throw FormatException('BookLoan.$key is invalid');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('BookLoan.$key is invalid');
    }
    return parsed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookLoan &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bookId == other.bookId &&
          borrower == other.borrower &&
          lentAt == other.lentAt &&
          dueAt == other.dueAt &&
          returnedAt == other.returnedAt;

  @override
  int get hashCode =>
      Object.hash(id, bookId, borrower, lentAt, dueAt, returnedAt);

  @override
  String toString() => 'BookLoan(id: $id, bookId: $bookId, '
      'borrower: $borrower, lentAt: $lentAt, dueAt: $dueAt, '
      'returnedAt: $returnedAt)';
}
