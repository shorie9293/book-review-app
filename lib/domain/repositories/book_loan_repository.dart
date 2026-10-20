import 'package:book_review_app/domain/models/book_loan.dart';

/// 貸出データの永続化を抽象化するリポジトリ。
abstract class BookLoanRepository {
  /// 全貸出を読み込む。
  Future<List<BookLoan>> loadLoans();

  /// 全貸出を保存する（既存内容は置換）。
  Future<void> saveLoans(List<BookLoan> loans);
}
