import '../../data/models/cloud_meal.dart';
import '../../data/ai_provider_repository.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../data/models/ai_provider.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';

/// ===========================================================================
/// AI prompt capsule with @ Meal Mention Autocomplete
///
/// The compose-side input of the assistant: a multi-line idea field with the
/// model picker, send button, and interactive @ mention autocomplete for
/// vault meals.
/// ===========================================================================
class AiPromptBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<AiProvider> providers;
  final Map<String, List<String>> customModels;
  final AiSelectedTarget? selectedTarget;
  final ValueChanged<AiSelectedTarget?> onTargetChanged;
  final VoidCallback onSubmit;
  final bool isGenerating;
  final List<CloudMeal> meals;
  final CloudMeal? mentionedMeal;
  final ValueChanged<CloudMeal?>? onMentionMealChanged;

  const AiPromptBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.providers,
    required this.customModels,
    required this.selectedTarget,
    required this.onTargetChanged,
    required this.onSubmit,
    required this.isGenerating,
    this.meals = const [],
    this.mentionedMeal,
    this.onMentionMealChanged,
  });

  @override
  State<AiPromptBar> createState() => _AiPromptBarState();
}

class _AiPromptBarState extends State<AiPromptBar> {
  String? _mentionQuery;
  int? _mentionStartIndex;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant AiPromptBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;

    // Clear active mention if its tag was deleted from the text
    if (widget.mentionedMeal != null &&
        !text.contains('@${widget.mentionedMeal!.name}')) {
      widget.onMentionMealChanged?.call(null);
    }

    final selection = widget.controller.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }

    final cursor = selection.baseOffset;
    if (cursor > text.length) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }

    final textBeforeCursor = text.substring(0, cursor);
    final lastAt = textBeforeCursor.lastIndexOf('@');
    if (lastAt == -1) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }

    // Must be preceded by start of text or whitespace/punctuation
    if (lastAt > 0) {
      final prevChar = textBeforeCursor[lastAt - 1];
      if (!RegExp(r'[\s\n(،,]').hasMatch(prevChar)) {
        if (_mentionQuery != null) setState(() => _mentionQuery = null);
        return;
      }
    }

    final textAfterAt = textBeforeCursor.substring(lastAt + 1);
    if (textAfterAt.contains('\n') || textAfterAt.length > 35) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }

    final query = textAfterAt.trim();
    if (_mentionQuery != query || _mentionStartIndex != lastAt) {
      setState(() {
        _mentionQuery = query;
        _mentionStartIndex = lastAt;
      });
    }
  }

  void _applyMention(CloudMeal meal) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final start = _mentionStartIndex ?? 0;

    final before = text.substring(0, start);
    final after = (cursor >= start && cursor <= text.length)
        ? text.substring(cursor)
        : '';

    final mentionTag = '@${meal.name} ';
    final newText = '$before$mentionTag$after';

    widget.controller.text = newText;
    final newCursor = before.length + mentionTag.length;
    widget.controller.selection = TextSelection.collapsed(offset: newCursor);

    widget.onMentionMealChanged?.call(meal);

    setState(() {
      _mentionQuery = null;
      _mentionStartIndex = null;
    });

    widget.focusNode.requestFocus();
  }

  List<CloudMeal> _getMatchingMeals() {
    if (widget.meals.isEmpty) return const [];
    final q = _mentionQuery?.toLowerCase() ?? '';
    if (q.isEmpty) {
      return widget.meals.take(8).toList();
    }
    return widget.meals
        .where((m) => m.name.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final matchingMeals = _getMatchingMeals();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: AiCapsule.ink,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // @ Mention Autocomplete Dropdown Panel
          if (_mentionQuery != null && widget.meals.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              constraints: const BoxConstraints(maxHeight: 210),
              decoration: BoxDecoration(
                color: AiCapsule.surface,
                borderRadius: BorderRadius.circular(AdminRadii.md),
                border: Border.all(color: AiCapsule.hairline),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      children: [
                        const Icon(
                          AdminIcons.meal,
                          size: 14,
                          color: AiCapsule.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'أكلات الخزنة المتاحة (@)',
                            style: adminText(
                              size: 11,
                              weight: FontWeight.w600,
                              color: AiCapsule.onInk,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _mentionQuery = null),
                          child: const Icon(
                            AdminIcons.close,
                            size: 14,
                            color: AiCapsule.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AiCapsule.hairline,
                  ),
                  if (matchingMeals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'لا توجد أكلة تطابق «$_mentionQuery»',
                        style: adminText(size: 11.5, color: AiCapsule.muted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: matchingMeals.length,
                        separatorBuilder: (context, _) => const Divider(
                          height: 1,
                          color: AiCapsule.hairline,
                        ),
                        itemBuilder: (context, index) {
                          final meal = matchingMeals[index];
                          return InkWell(
                            onTap: () => _applyMention(meal),
                            hoverColor: Colors.white.withValues(alpha: 0.06),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    AdminIcons.meal,
                                    size: 15,
                                    color: AiCapsule.accent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      meal.name,
                                      style: adminText(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                        color: AiCapsule.onInk,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (meal.category.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AiCapsule.ink,
                                        borderRadius: BorderRadius.circular(
                                          AdminRadii.sm,
                                        ),
                                      ),
                                      child: Text(
                                        meal.category,
                                        style: adminText(
                                          size: 10,
                                          color: AiCapsule.muted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: !widget.isGenerating,
            maxLines: 2,
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
          // Active Mention Tag Badge
          if (widget.mentionedMeal != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AiCapsule.surface,
                    borderRadius: BorderRadius.circular(AdminRadii.sm),
                    border: Border.all(
                      color: AiCapsule.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        AdminIcons.meal,
                        size: 13,
                        color: AiCapsule.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'وجبة مرتبطة (RAG): ${widget.mentionedMeal!.name}',
                        style: adminText(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AiCapsule.onInk,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => widget.onMentionMealChanged?.call(null),
                        child: const Icon(
                          AdminIcons.close,
                          size: 12,
                          color: AiCapsule.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              _SendButton(
                tooltip: strings.aiSendTooltip,
                onPressed: widget.isGenerating ? null : widget.onSubmit,
                isLoading: widget.isGenerating,
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _ModelDropdownPill(
                    providers: widget.providers,
                    customModels: widget.customModels,
                    selected: widget.selectedTarget,
                    onChanged: widget.onTargetChanged,
                  ),
                ),
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
  final Map<String, List<String>> customModels;
  final AiSelectedTarget? selected;
  final ValueChanged<AiSelectedTarget?> onChanged;

  const _ModelDropdownPill({
    required this.providers,
    required this.customModels,
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
        for (final group in _AiModelCatalog.getGroups(widget.customModels).where((g) => g.options.isNotEmpty))
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
  static List<_AiModelGroup> getGroups(Map<String, List<String>> customModels) {
    List<String> modelsFor(String provider) {
      final list = customModels[provider];
      if (list != null && list.isNotEmpty) return list;
      return defaultAiModels[provider] ?? const [];
    }

    return [
      _AiModelGroup(
        provider: 'gemini',
        icon: Icons.bubble_chart_rounded,
        options: modelsFor('gemini').map((m) => _AiModelOption(
          model: m, label: m, pillLabel: 'Gemini: $m',
        )).toList(),
      ),
      _AiModelGroup(
        provider: 'groq',
        icon: Icons.speed_rounded,
        options: modelsFor('groq').map((m) => _AiModelOption(
          model: m, label: m, pillLabel: 'Groq: $m',
        )).toList(),
      ),
      _AiModelGroup(
        provider: 'openrouter',
        icon: Icons.alt_route_rounded,
        options: modelsFor('openrouter').map((m) => _AiModelOption(
          model: m, label: m, pillLabel: 'OpenRouter: $m',
        )).toList(),
      ),
    ];
  }

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
