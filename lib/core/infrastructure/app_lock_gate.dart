import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../testing/app_keys.dart';
import 'app_lock_repository.dart';
import 'app_lock_service.dart';
import 'lock_attempt_policy.dart';
import 'lock_reload_policy.dart';

/// アプリロック有効時に全UIを隠すゲートWidget。
/// repository は注入可能（試練用）。無指定時は Hive 実装。
/// 読込例外・生成失敗は握りつぶして素通り（fail-open）。
class AppLockGate extends StatefulWidget {
  final WidgetBuilder unlockedBuilder;
  final AppLockRepository? repository;

  /// 現在時刻の供給（試練用）。
  final DateTime Function()? now;

  /// 再施錠猶予の上書き（試練用・無指定は設定値）。
  final Duration? graceOverride;

  const AppLockGate({
    super.key,
    required this.unlockedBuilder,
    this.repository,
    this.now,
    this.graceOverride,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  AppLockService? _service;
  bool _initialized = false;
  bool _locked = false;
  bool _obscure = true;
  final _codeController = TextEditingController();
  String? _error;
  DateTime? _backgroundedAt;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  Duration get _grace => widget.graceOverride ?? _service?.relockGrace ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    try {
      final repo = widget.repository ?? const HiveAppLockRepository();
      final service = AppLockService(repo, now: widget.now ?? DateTime.now);
      final locked = service.isLocked;
      if (!mounted) return;
      setState(() {
        _service = service;
        _locked = locked;
        _initialized = true;
      });
    } catch (_) {
      // Hive 未初期化等は素通り（fail-open）。
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _locked = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _backgroundedAt ??= _now();
      case AppLifecycleState.resumed:
        final service = _service;
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (service == null || !service.isLocked) return;
        if (!LockReloadPolicy.shouldRelock(
          backgroundedAt,
          _now(),
          _grace,
        )) {
          return;
        }
        if (!mounted) return;
        setState(() {
          _locked = true;
          _error = null;
          _passcodeFieldClear();
        });
      case AppLifecycleState.detached:
        break;
    }
  }

  void _passcodeFieldClear() {
    _codeController.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final service = _service;
    if (service == null) return;
    if (service.isLockedOut) {
      setState(
        () => _error = LockAttemptPolicy.lockoutLabel(
          service.lockoutRemainingSeconds,
        ),
      );
      return;
    }
    final ok = await service.unlock(passcode: _codeController.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _locked = false;
        _error = null;
      });
    } else {
      final lockedOut = service.isLockedOut;
      setState(() {
        _error = lockedOut
            ? LockAttemptPolicy.lockoutLabel(service.lockoutRemainingSeconds)
            : 'パスコードが正しくありません';
      });
    }
    _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locked) {
      return widget.unlockedBuilder(context);
    }
    final service = _service;
    final lockedOut = service?.isLockedOut ?? false;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              const Text('このアプリはロックされています'),
              const SizedBox(height: 24),
              TextField(
                key: AppKeys.appLockGateField,
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: _obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'パスコード',
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              if (lockedOut)
                Text(
                  LockAttemptPolicy.lockoutLabel(
                    service?.lockoutRemainingSeconds ?? 0,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: lockedOut ? null : _submit,
                child: const Text('ロック解除'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
