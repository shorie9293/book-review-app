/// 非同期読み込みの「失敗」と「0件」を明確に分離するための基盤。
///
/// UI 側はこの型だけを見て、読み込み中 / 表示 / 空 / 失敗 を出し分ける。
/// 失敗時も直近のデータを保持できるよう、状態は値を持ち替える形にする。
library;

/// 読み込みの局面。
enum LoadPhase { loading, data, empty, error }

/// 画面が取り得る読み込み状態。
///
/// - [LoadState.loading] 読み込み中
/// - [LoadState.data] 取得済み（1件以上）
/// - [LoadState.empty] 取得成功だが0件（失敗ではない）
/// - [LoadState.error] 取得失敗（[LoadState.empty] とは別物）
///
/// 不正引数（data に null / error に空文字）は [ArgumentError]。
/// 既定コンストラクタは公開せず、名前付きファクトリのみを許す。
class LoadState<T> {
  const LoadState._({
    required this.phase,
    this.value,
    this.message,
    this.retryable = true,
    this.cause,
  });

  /// 読み込み中。
  factory LoadState.loading() => const LoadState._(phase: LoadPhase.loading);

  /// 取得済み。null は不正。
  factory LoadState.data(T value) {
    if (value == null) {
      throw ArgumentError.value(value, 'value', 'data に null は指定できません');
    }
    return LoadState._(phase: LoadPhase.data, value: value);
  }

  /// 取得成功かつ0件。
  factory LoadState.empty() => const LoadState._(phase: LoadPhase.empty);

  /// 取得失敗。[message] が空文字・空白のみなら不正。
  factory LoadState.error(
    String message, {
    bool retryable = true,
    Object? cause,
  }) {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(message, 'message', 'error の message は必須です');
    }
    return LoadState._(
      phase: LoadPhase.error,
      message: message,
      retryable: retryable,
      cause: cause,
    );
  }

  final LoadPhase phase;

  /// [LoadPhase.data] のときのみ非null。
  final T? value;

  /// [LoadPhase.error] のときのみ非null。
  final String? message;

  /// 再試行して良い失敗か。
  final bool retryable;

  /// 元の例外（等価判定には含めない）。
  final Object? cause;

  bool get isLoading => phase == LoadPhase.loading;

  bool get isData => phase == LoadPhase.data;

  bool get isEmpty => phase == LoadPhase.empty;

  bool get isError => phase == LoadPhase.error;

  /// 局面ごとの分岐。全局面を網羅させるため required で受ける。
  R when<R>({
    required R Function() loading,
    required R Function(T value) data,
    required R Function() empty,
    required R Function(String message, bool retryable) error,
  }) {
    switch (phase) {
      case LoadPhase.loading:
        return loading();
      case LoadPhase.data:
        return data(value as T);
      case LoadPhase.empty:
        return empty();
      case LoadPhase.error:
        return error(message ?? '', retryable);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadState<T> &&
          other.phase == phase &&
          other.value == value &&
          other.message == message &&
          other.retryable == retryable;

  @override
  int get hashCode => Object.hash(phase, value, message, retryable);

  @override
  String toString() {
    switch (phase) {
      case LoadPhase.loading:
        return 'LoadState<$T>.loading()';
      case LoadPhase.data:
        return 'LoadState<$T>.data($value)';
      case LoadPhase.empty:
        return 'LoadState<$T>.empty()';
      case LoadPhase.error:
        return 'LoadState<$T>.error($message, retryable: $retryable)';
    }
  }
}

/// 読み込み結果。例外を投げずに失敗を値として返す。
///
/// [LoadState.error] と違い自由な値を保持しないため、リポジトリ層の
/// 戻り値として使う。
class LoadResult<T> {
  const LoadResult._({
    required bool success,
    T? value,
    String? message,
    bool retryable = true,
    Object? cause,
  })  : _success = success,
        _value = value,
        _message = message,
        _retryable = retryable,
        _cause = cause;

  /// 成功。null は不正。
  factory LoadResult.success(T value) {
    if (value == null) {
      throw ArgumentError.value(value, 'value', 'success に null は指定できません');
    }
    return LoadResult._(success: true, value: value);
  }

  /// 失敗。[message] が空文字・空白のみなら不正。
  factory LoadResult.failure(
    String message, {
    bool retryable = true,
    Object? cause,
  }) {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(
        message,
        'message',
        'failure の message は必須です',
      );
    }
    return LoadResult._(
      success: false,
      message: message,
      retryable: retryable,
      cause: cause,
    );
  }

  final bool _success;
  final T? _value;
  final String? _message;
  final bool _retryable;
  final Object? _cause;

  bool get isSuccess => _success;

  bool get isFailure => !_success;

  /// 成功時のみ非null。
  T? get valueOrNull => _value;

  /// 失敗時のみ非null。
  String? get message => _message;

  /// 再試行して良い失敗か（成功時は true）。
  bool get retryable => _retryable;

  /// 元の例外（等価判定には含めない）。
  Object? get cause => _cause;

  R when<R>({
    required R Function(T value) success,
    required R Function(String message, bool retryable) failure,
  }) {
    if (_success) return success(_value as T);
    return failure(_message ?? '', _retryable);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadResult<T> &&
          other._success == _success &&
          other._value == _value &&
          other._message == _message &&
          other._retryable == _retryable;

  @override
  int get hashCode => Object.hash(_success, _value, _message, _retryable);

  @override
  String toString() => _success
      ? 'LoadResult<$T>.success($_value)'
      : 'LoadResult<$T>.failure($_message, retryable: $_retryable)';
}
