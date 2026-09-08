import 'package:flutter/material.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:book_review_app/features/challenge/presentation/viewmodel/challenge_view_model.dart';

/// 年間読書チャレンジ画面。
///
/// 年間目標冊数を設定し、今年の読了進捗を可視化、達成時はバッジを表示する。
class ChallengeScreen extends StatefulWidget {
  final ChallengeRepository? repository;

  const ChallengeScreen({super.key, this.repository});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final ChallengeViewModel _viewModel = ChallengeViewModel();
  ChallengeRepository? _repository;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.repository != null) {
      _repository = widget.repository;
    } else {
      final repo = HiveChallengeRepository();
      await repo.init();
      _repository = repo;
    }
    _viewModel.addListener(_handleViewModelChange);
    await _viewModel.load(_repository!);
  }

  void _handleViewModelChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChange);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _editTarget() async {
    final controller = TextEditingController(
      text: _viewModel.target == 0 ? '' : '${_viewModel.target}',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('年間目標冊数を設定'),
        content: TextField(
          key: const Key('challenge_target_field'),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '目標冊数',
            hintText: '例: 12',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            key: const Key('challenge_target_save'),
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(context, parsed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // 注: ダイアログの退場アニメーション中も TextField が controller を参照するため、
    // pop 直後の dispose は避ける（短命なダイアログ内 controller はGCに任せる）。
    if (result != null && result > 0) {
      await _viewModel.setTarget(_repository!, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_challenge'),
      appBar: AppBar(title: const Text('年間読書チャレンジ')),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProgressCard(context),
          const SizedBox(height: 16),
          TextButton.icon(
            key: const Key('challenge_edit_button'),
            onPressed: _editTarget,
            icon: const Icon(Icons.edit),
            label: Text(
              _viewModel.target == 0 ? '目標を設定する' : '目標を変更する',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final target = _viewModel.target;
    final read = _viewModel.read;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📚 ${DateTime.now().year}年の読書チャレンジ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (target == 0)
              const Text('目標冊数を設定すると進捗を記録できます。')
            else ...[
              LinearProgressIndicator(
                key: const Key('challenge_progress'),
                value: _viewModel.progress,
                minHeight: 12,
              ),
              const SizedBox(height: 8),
              Text(
                '$read / $target 冊読了',
                style: const TextStyle(fontSize: 16),
              ),
              if (_viewModel.isAchieved) ...[
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.emoji_events, color: Color(0xFFFFB300), size: 32),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🎉 年間目標達成！よく頑張りました！',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
