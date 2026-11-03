import 'package:flutter/material.dart';

import '../testing/app_keys.dart';
import 'app_lock_repository.dart';
import 'app_lock_service.dart';
import 'lock_reload_policy.dart';

/// 設定画面: パスコードによるアプリロックの有効化/無効化。
class AppLockSettingsScreen extends StatefulWidget {
  final AppLockRepository? repository;
  const AppLockSettingsScreen({super.key, this.repository});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  AppLockService? _service;
  bool _enabled = false;
  int _graceSeconds = 0;
  final _passcodeController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final repo = widget.repository ?? const HiveAppLockRepository();
      final service = AppLockService(repo);
      final enabled = service.isLocked;
      final grace = service.relockGrace.inSeconds;
      if (!mounted) return;
      setState(() {
        _service = service;
        _enabled = enabled;
        _graceSeconds = grace;
      });
    } catch (_) {
      // Hive 未初期化等は読込不能 → 無効扱いで表示（fail-open）。
      if (!mounted) return;
      setState(() => _initializedFailed());
    }
  }

  void _initializedFailed() {
    _service = null;
    _enabled = false;
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    setState(() => _error = null);
    final code = _passcodeController.text;
    if (code != _confirmController.text) {
      setState(() => _error = '確認用パスコードと一致しません');
      return;
    }
    try {
      await _service!.enableWithPasscode(code);
    } on ArgumentError {
      setState(() => _error = '4桁の数字を入力してください');
      return;
    }
    if (!mounted) return;
    setState(() => _enabled = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('アプリロックを有効にしました')));
  }

  Future<void> _disable() async {
    await _service!.disable();
    if (!mounted) return;
    setState(() => _enabled = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('アプリロックを無効にしました')));
  }

  /// 選択肢に無い保存値は「即時」として扱う（DropdownButton の value 制約）。
  int get _graceValue =>
      LockReloadPolicy.graceOptionsSeconds.contains(_graceSeconds)
          ? _graceSeconds
          : 0;

  Future<void> _setGrace(int seconds) async {
    await _service?.setRelockGrace(Duration(seconds: seconds));
    if (!mounted) return;
    setState(() => _graceSeconds = seconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.appLockScreen,
      appBar: AppBar(title: const Text('アプリロック')),
      body: _service == null
          ? const Center(child: CircularProgressIndicator())
          : _enabled
              ? SingleChildScrollView(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock, size: 48),
                          const Text('アプリロック有効'),
                          const SizedBox(height: 16),
                          DropdownButton<int>(
                            key: AppKeys.appLockGraceDropdown,
                            value: _graceValue,
                            items: [
                              for (final seconds
                                  in LockReloadPolicy.graceOptionsSeconds)
                                DropdownMenuItem<int>(
                                  value: seconds,
                                  child: Text(
                                    '復帰時に再施錠: '
                                    '${LockReloadPolicy.graceLabel(seconds)}',
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) _setGrace(value);
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            key: AppKeys.appLockDisableButton,
                            onPressed: _disable,
                            child: const Text('無効にする'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        key: AppKeys.appLockPasscodeField,
                        controller: _passcodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '新しいパスコード（4桁）',
                        ),
                      ),
                      TextField(
                        key: AppKeys.appLockConfirmField,
                        controller: _confirmController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '確認用パスコード',
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: AppKeys.appLockEnableButton,
                        onPressed: _enable,
                        child: const Text('有効にする'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
