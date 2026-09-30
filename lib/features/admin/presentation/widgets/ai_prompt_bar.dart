import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../data/models/ai_provider.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';

/// ===========================================================================
/// AI prompt capsule
///
/// The compose-side input of the assistant: a multi-line idea field with the
/// model picker and the send button on the row underneath, all wrapped in one
/// dark-olive capsule.
///
/// The controller and the focus node belong to the parent panel — the welcome
/// chips write straight into this field — so this widget never disposes them.
/// ===========================================================================
class AiPromptBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<AiProvider> providers;
  final AiSelectedTarget? selectedTarget;
  final ValueChanged<AiSelectedTarget?> onTargetChanged;
  final VoidCallback onSubmit;
  final bool isGenerating;

  const AiPromptBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.providers,
    required this.selectedTarget,
    required this.onTargetChanged,
    required this.onSubmit,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: AiCapsule.ink,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !isGenerating,
            maxLines: 3,
            maxLength: 600,
            textDirection: TextDirection.rtl,
            style: adminText(size: 13, color: AiCapsule.onInk, height: 1.8),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: strings.aiPromptCapsuleHint,
              hintStyle: adminText(
                size: 12,
                color: AiCapsule.muted,
                height: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _ModelDropdownPill(
                  providers: providers,
                  selected: selectedTarget,
                  onChanged: onTargetChanged,
                ),
              ),
              const SizedBox(width: 12),
              _SendButton(
                tooltip: strings.aiSendTooltip,
                onPressed: isGenerating ? null : onSubmit,
                isLoading: isGenerating,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Capsule palette
/// ---------------------------------------------------------------------------
/// The prompt capsule is the one dark island in the adopted light library —
/// the mockups keep every other surface pale and let only this capsule go deep
/// olive, so it holds its own values in both dashboard themes instead of
/// following [AdminPalette]; every other colour in the assistant stays
/// token-driven.
abstract final class AiCapsule {
  /// Capsule body.
  static const Color ink = Color(0xFF2B3B31);

  /// Model picker pill, menu surface and hover fills.
  static const Color surface = Color(0xFF344337);

  /// Send button.
  static const Color accent = Color(0xFF86A874);

  /// Placeholder and muted labels sitting on [ink].
  static const Color muted = Color(0xFFA1AE9A);

  /// Primary text sitting on [ink].
  static const Color onInk = Color(0xFFD7DFD1);

  /// Hairline that separates a menu group from the surface behind it.
  static const Color hairline = Color(0x33FFFFFF);
}

/// ---------------------------------------------------------------------------
/// Model selector
/// ---------------------------------------------------------------------------
/// A pill showing the active target; tapping it opens a cascading menu where
/// every provider group flies out into the models it serves. The list of
/// groups is static ([_AiModelCatalog]) — the Firestore documents only supply
/// the API keys, so an empty collection just disables the picker.
class _ModelDropdownPill extends StatefulWidget {
  final List<AiProvider> providers;
  final AiSelectedTarget? selected;
  final ValueChanged<AiSelectedTarget?> onChanged;

  const _ModelDropdownPill({
    required this.providers,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_ModelDropdownPill> createState() => _ModelDropdownPillState();
}

class _ModelDropdownPillState extends State<_ModelDropdownPill> {
  final MenuController _menuController = MenuController();

  bool get _hasChoices => widget.providers.isNotEmpty;

  void _toggleMenu() {
    if (!_hasChoices) return;
    _menuController.isOpen ? _menuController.close() : _menuController.open();
  }

  /// Reserves the slot on every row so the labels stay aligned; an invisible
  /// tick would otherwise shift the text of the unselected items.
  Widget _checkIcon(bool isSelected) {
    return Icon(
      AdminIcons.check,
      size: 18,
      color: isSelected ? AiCapsule.accent : Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final selected = widget.selected;

    return MenuAnchor(
      controller: _menuController,
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll<Color>(AiCapsule.surface),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: const WidgetStatePropertyAll<double>(12),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminRadii.md),
          ),
        ),
        side: const WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: AiCapsule.hairline),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: _checkIcon(selected == null),
          onPressed: () => widget.onChanged(null),
          child: Text(
            strings.aiAutoMode,
            style: adminText(
              size: 13,
              weight: FontWeight.w700,
              color: AiCapsule.onInk,
            ),
          ),
        ),
        const Divider(height: 10, thickness: 1, color: AiCapsule.hairline),
        for (final group in _AiModelCatalog.groups)
          SubmenuButton(
            style: const ButtonStyle(
              foregroundColor: WidgetStatePropertyAll<Color>(AiCapsule.muted),
            ),
            leadingIcon: Icon(group.icon, size: 16, color: AiCapsule.muted),
            menuChildren: [
              for (final option in group.options)
                MenuItemButton(
                  leadingIcon: _checkIcon(
                    selected?.provider == group.provider &&
                        selected?.model == option.model,
                  ),
                  onPressed: () => widget.onChanged(
                    AiSelectedTarget(
                      provider: group.provider,
                      model: option.model,
                      displayName: option.pillLabel ?? option.label,
                    ),
                  ),
                  child: Text(
                    option.label,
                    textDirection: TextDirection.ltr,
                    style: adminText(size: 12.5, color: AiCapsule.onInk),
                  ),
                ),
            ],
            child: Text(
              _AiModelCatalog.labelFor(strings, group.provider),
              style: adminText(
                size: 13,
                weight: FontWeight.w600,
                color: AiCapsule.onInk,
              ),
            ),
          ),
      ],
      child: Tooltip(
        message: strings.aiSelectModel,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AdminRadii.pill),
          child: InkWell(
            onTap: _toggleMenu,
            customBorder: const StadiumBorder(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AiCapsule.surface,
                borderRadius: BorderRadius.circular(AdminRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AdminIcons.aiMagic,
                    size: 14,
                    color: _hasChoices ? AiCapsule.accent : AiCapsule.muted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      selected?.displayName ?? strings.aiAutoMode,
                      textDirection: selected == null
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      overflow: TextOverflow.ellipsis,
                      style: adminText(
                        size: 12,
                        weight: FontWeight.w600,
                        color: _hasChoices ? AiCapsule.onInk : AiCapsule.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(AdminIcons.expand, size: 16, color: AiCapsule.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Model catalog
/// ---------------------------------------------------------------------------
/// Provider key, icon and the models offered under it. Model ids and their
/// display names are product identifiers rather than copy, so they live here
/// and only the group heading goes through [AppStrings].
class _AiModelOption {
  final String model;
  final String label;

  /// Shown on the pill instead of [label] when the model name alone does not
  /// say which provider serves it.
  final String? pillLabel;

  const _AiModelOption({
    required this.model,
    required this.label,
    this.pillLabel,
  });
}

class _AiModelGroup {
  final String provider;
  final IconData icon;
  final List<_AiModelOption> options;

  const _AiModelGroup({
    required this.provider,
    required this.icon,
    required this.options,
  });
}

abstract final class _AiModelCatalog {
  static const List<_AiModelGroup> groups = [
    _AiModelGroup(
      provider: 'gemini',
      icon: Icons.bubble_chart_rounded,
      options: [
        _AiModelOption(
          model: 'gemini-2.5-flash',
          label: 'Gemini 2.5 Flash',
          pillLabel: 'Gemini: 2.5 Flash',
        ),
        _AiModelOption(
          model: 'gemini-2.0-flash',
          label: 'Gemini 2.0 Flash',
          pillLabel: 'Gemini: 2.0 Flash',
        ),
        _AiModelOption(
          model: 'gemini-2.5-pro',
          label: 'Gemini 2.5 Pro',
          pillLabel: 'Gemini: 2.5 Pro',
        ),
        _AiModelOption(
          model: 'gemini-2.5-flash',
          label: 'Gemini 2.5 Flash',
          pillLabel: 'Gemini: 2.5 Flash',
        ),
      ],
    ),
    _AiModelGroup(
      provider: 'groq',
      icon: Icons.speed_rounded,
      options: [
        _AiModelOption(
          model: 'llama-3.3-70b-versatile',
          label: 'Llama 3.3 70B',
          pillLabel: 'Groq: Llama 3.3 70B',
        ),
        _AiModelOption(
          model: 'openai/gpt-oss-120b',
          label: 'GPT-OSS 120B',
          pillLabel: 'Groq: GPT-OSS 120B',
        ),
        _AiModelOption(
          model: 'deepseek-r1-distill-llama-70b',
          label: 'DeepSeek R1 Distill 70B',
          pillLabel: 'Groq: DeepSeek R1 70B',
        ),
        _AiModelOption(
          model: 'qwen/qwen3-32b',
          label: 'Qwen 3 32B',
          pillLabel: 'Groq: Qwen 3 32B',
        ),
        _AiModelOption(
          model: 'allam-2-7b',
          label: 'Allam 2 7B (علام)',
          pillLabel: 'Groq: Allam 2 7B (علام)',
        ),
        _AiModelOption(
          model: 'llama-3.1-8b-instant',
          label: 'Llama 3.1 8B Instant',
          pillLabel: 'Groq: Llama 3.1 8B',
        ),
      ],
    ),
    _AiModelGroup(
      provider: 'openrouter',
      icon: Icons.alt_route_rounded,
      options: [
        _AiModelOption(
          model: 'openrouter/free',
          label: 'Auto Free Router',
          pillLabel: 'OpenRouter: Auto Free',
        ),
        _AiModelOption(
          model: 'meta-llama/llama-3.3-70b-instruct:free',
          label: 'Llama 3.3 70B (Free)',
          pillLabel: 'OpenRouter: Llama 3.3 (Free)',
        ),
        _AiModelOption(
          model: 'deepseek/deepseek-r1:free',
          label: 'DeepSeek R1 (Free)',
          pillLabel: 'OpenRouter: DeepSeek R1 (Free)',
        ),
        _AiModelOption(
          model: 'deepseek/deepseek-chat:free',
          label: 'DeepSeek Chat (Free)',
          pillLabel: 'OpenRouter: DeepSeek Chat (Free)',
        ),
        _AiModelOption(
          model: 'qwen/qwen3-coder-30b-a3b-instruct:free',
          label: 'Qwen 3 Coder 30B (Free)',
          pillLabel: 'OpenRouter: Qwen 3 Coder (Free)',
        ),
      ],
    ),
  ];

  static String labelFor(AppStrings strings, String provider) {
    return switch (provider) {
      'gemini' => strings.aiProviderGoogle,
      'groq' => strings.aiProviderGroq,
      'openrouter' => strings.aiProviderOpenRouter,
      _ => provider,
    };
  }
}

/// ---------------------------------------------------------------------------
/// Send action
/// ---------------------------------------------------------------------------
/// Circular send button that turns into a spinner while a request is in flight.
class _SendButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SendButton({
    required this.tooltip,
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AiCapsule.accent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AiCapsule.onInk,
                      ),
                    )
                  : const Icon(
                      AdminIcons.aiSend,
                      size: 20,
                      color: AiCapsule.onInk,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
