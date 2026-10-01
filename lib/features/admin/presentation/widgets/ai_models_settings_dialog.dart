import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../data/ai_provider_repository.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';
import 'admin_toast.dart';

class AiModelsSettingsDialog extends ConsumerStatefulWidget {
  const AiModelsSettingsDialog({super.key});

  @override
  ConsumerState<AiModelsSettingsDialog> createState() =>
      _AiModelsSettingsDialogState();
}

class _AiModelsSettingsDialogState
    extends ConsumerState<AiModelsSettingsDialog> {
  final TextEditingController _modelController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const List<Map<String, String>> _providerDefs = [
    {
      'key': 'gemini',
      'label': 'Gemini',
      'badge': 'Google AI Studio',
    },
    {
      'key': 'groq',
      'label': 'Groq',
      'badge': 'Groq Cloud',
    },
    {
      'key': 'openrouter',
      'label': 'OpenRouter',
      'badge': 'OpenRouter API',
    },
  ];

  int _selectedProviderIndex = 0;
  bool _isSaving = false;

  String get _currentProviderKey => _providerDefs[_selectedProviderIndex]['key']!;

  @override
  void dispose() {
    _modelController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addModel(List<String> currentModels) async {
    final strings = AppStrings.of(context);
    final newModel = _modelController.text.trim();
    if (newModel.isEmpty) return;

    if (currentModels.contains(newModel)) {
      showAdminToast(
        context,
        message: strings.aiModelsSettingsModelExists,
        kind: AdminToastKind.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = [...currentModels, newModel];
      await ref
          .read(aiProviderRepositoryProvider)
          .updateCustomModels(_currentProviderKey, updated);
      _modelController.clear();
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeModel(List<String> currentModels, String model) async {
    setState(() => _isSaving = true);
    try {
      final updated = currentModels.where((m) => m != model).toList();
      await ref
          .read(aiProviderRepositoryProvider)
          .updateCustomModels(_currentProviderKey, updated);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final strings = AppStrings.of(context);
    final modelsMap = ref.watch(customAiModelsStreamProvider).valueOrNull ??
        defaultAiModels;
    final currentModels = modelsMap[_currentProviderKey] ??
        defaultAiModels[_currentProviderKey] ??
        const <String>[];

    return AdminDialogShell(
      title: strings.aiModelsSettingsTitle,
      subtitle: strings.aiModelsSettingsSubtitle,
      icon: AdminIcons.settings,
      tone: AdminDialogTone.brand,
      maxWidth: 560,
      actions: [
        AdminDialogButtons.ghost(
          p,
          label: strings.aiModelsSettingsClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ------------------------------------ Provider Segmented Tabs ---
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(AdminRadii.md),
              border: Border.all(color: p.borderStrong),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _providerDefs.length; i++)
                  Expanded(
                    child: _buildProviderSegment(
                      p,
                      index: i,
                      item: _providerDefs[i],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ---------------------------------------- Input + Add Button ---
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _modelController,
                  focusNode: _focusNode,
                  textDirection: TextDirection.ltr,
                  style: adminLatinText(size: 13, color: p.ink),
                  decoration: adminFieldDeco(
                    p,
                    label: strings.aiModelsSettingsAddHint,
                    hint: strings.aiModelsSettingsAddHint,
                    floatingLabel: false,
                    icon: AdminIcons.aiSparkle,
                  ),
                  onSubmitted: (_) => _addModel(currentModels),
                ),
              ),
              const SizedBox(width: 10),
              AdminDialogButtons.primary(
                p,
                label: strings.aiModelsSettingsAddBtn,
                tone: AdminDialogTone.brand,
                icon: AdminIcons.add,
                loading: _isSaving,
                onPressed: _isSaving ? null : () => _addModel(currentModels),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ----------------------------------------------- Models List ---
          Container(
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 280),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(AdminRadii.md),
              border: Border.all(color: p.border),
            ),
            child: currentModels.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AdminIcons.searchOff,
                            size: 26,
                            color: p.inkFaint,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            strings.aiModelsSettingsEmpty,
                            style: adminText(size: 12.5, color: p.inkMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: currentModels.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final model = currentModels[index];
                      return _buildModelRow(
                        p,
                        strings,
                        model: model,
                        currentModels: currentModels,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSegment(
    AdminPalette p, {
    required int index,
    required Map<String, String> item,
  }) {
    final active = _selectedProviderIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedProviderIndex != index) {
          setState(() {
            _selectedProviderIndex = index;
            _modelController.clear();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? p.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AdminRadii.sm),
          border: active ? Border.all(color: p.borderStrong) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? p.claySolid : p.inkFaint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              item['label']!,
              style: adminLatinText(
                size: 12.5,
                weight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? p.ink : p.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelRow(
    AdminPalette p,
    AppStrings strings, {
    required String model,
    required List<String> currentModels,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AdminRadii.sm),
        border: Border.all(color: p.borderStrong),
      ),
      child: Row(
        children: [
          Icon(
            AdminIcons.aiSparkle,
            size: 14,
            color: p.claySolid,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              model,
              style: adminLatinText(
                size: 12.5,
                weight: FontWeight.w600,
                color: p.ink,
              ),
              textDirection: TextDirection.ltr,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              AdminIcons.delete,
              size: 16,
              color: p.chiliSolid,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: strings.aiModelsSettingsDeleteTooltip,
            onPressed: _isSaving ? null : () => _removeModel(currentModels, model),
          ),
        ],
      ),
    );
  }
}
