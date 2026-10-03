import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../data/admin_auth_service.dart';
import '../../data/models/cloud_meal.dart';
import '../../data/vault_admin_repository.dart';
import '../../domain/duplicate_candidate.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';
import 'admin_toast.dart';

/// Modal dialog for reviewing, ignoring, or deleting duplicate and similar meals.
class DeduplicationDialog extends ConsumerStatefulWidget {
  const DeduplicationDialog({super.key});

  @override
  ConsumerState<DeduplicationDialog> createState() =>
      _DeduplicationDialogState();
}

class _DeduplicationDialogState extends ConsumerState<DeduplicationDialog> {
  bool _isLoading = true;
  bool _isCleaningAll = false;
  bool _checkById = false;
  String? _errorMessage;
  List<DuplicatePairCandidate> _pairs = [];
  final Set<String> _processingPairKeys = {};

  @override
  void initState() {
    super.initState();
    _loadAndDetectDuplicates();
  }

  Future<void> _loadAndDetectDuplicates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(vaultAdminRepositoryProvider);
      final candidates = await repo.detectDuplicateCandidates(checkById: _checkById);

      if (mounted) {
        setState(() {
          _pairs = candidates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDeletePair(
    DuplicatePairCandidate pair,
    AppStrings strings,
  ) async {
    final key = pair.pairKey;
    final deletedId = pair.duplicateMeal.id;

    setState(() => _processingPairKeys.add(key));

    try {
      await ref.read(vaultAdminRepositoryProvider).deleteVaultMeal(deletedId);

      if (mounted) {
        setState(() {
          // Transitive pair pruning: prune all candidate pairs containing the deleted meal ID
          // whether as duplicate or original to preserve dataset consistency.
          _pairs.removeWhere((p) =>
              p.duplicateMeal.id == deletedId || p.originalMeal.id == deletedId);
          _processingPairKeys.remove(key);
        });

        showAdminToast(
          context,
          message: strings.vaultDeduplicationDeletedSuccess(
            pair.duplicateMeal.name,
          ),
          kind: AdminToastKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingPairKeys.remove(key));
        showAdminToast(
          context,
          message: strings.vaultDeduplicationErrorToast(e.toString()),
          kind: AdminToastKind.error,
        );
      }
    }
  }

  Future<void> _handleIgnorePair(
    DuplicatePairCandidate pair,
    AppStrings strings,
  ) async {
    final key = pair.pairKey;
    setState(() => _processingPairKeys.add(key));

    try {
      String? adminId;
      try {
        final adminUser = ref.read(adminAuthProvider).currentUser;
        adminId = adminUser?.uid ?? adminUser?.email;
      } catch (_) {
        // Fallback for isolated widget test environments without auth
        adminId = null;
      }

      await ref.read(vaultAdminRepositoryProvider).ignoreDuplicatePair(
            mealA: pair.originalMeal,
            mealB: pair.duplicateMeal,
            similarity: pair.similarity,
            adminId: adminId,
          );

      if (mounted) {
        setState(() {
          _pairs.removeWhere((p) => p.pairKey == key);
          _processingPairKeys.remove(key);
        });

        showAdminToast(
          context,
          message: strings.vaultDeduplicationIgnoredSuccess(
            pair.originalMeal.name,
            pair.duplicateMeal.name,
          ),
          kind: AdminToastKind.info,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingPairKeys.remove(key));
        showAdminToast(
          context,
          message: strings.vaultDeduplicationErrorToast(e.toString()),
          kind: AdminToastKind.error,
        );
      }
    }
  }

  Future<void> _handleCleanAllRemaining(
    AppStrings strings,
    AdminPalette p,
  ) async {
    if (_pairs.isEmpty) return;

    final duplicateIds = _pairs
        .where((p) => p.similarity >= 0.95)
        .map((p) => p.duplicateMeal.id)
        .toSet()
        .toList();

    if (duplicateIds.isEmpty) return;

    final confirmed = await showAdminConfirmDialog(
      context: context,
      icon: AdminIcons.cleanup,
      tone: AdminDialogTone.danger,
      title: strings.vaultDeduplicationConfirmCleanAllTitle,
      message:
          strings.vaultDeduplicationConfirmCleanAllMessage(duplicateIds.length),
      confirmLabel: strings.vaultDeduplicationConfirmCleanAllConfirm,
      cancelLabel: strings.vaultDeduplicationConfirmCleanAllCancel,
      confirmIcon: AdminIcons.cleanup,
      note: AdminDialogNote(
        tone: AdminDialogTone.danger,
        icon: AdminIcons.warning,
        badge: strings.vaultDeduplicationConfirmCleanAllNoteBadge,
        title: strings.vaultDeduplicationConfirmCleanAllNoteTitle,
      ),

    );

    if (!confirmed || !mounted) return;

    setState(() => _isCleaningAll = true);
    try {
      final count = await ref
          .read(vaultAdminRepositoryProvider)
          .deleteDuplicateMealsBatch(duplicateIds);

      if (mounted) {
        final deletedSet = duplicateIds.toSet();
        setState(() {
          _pairs.removeWhere((p) =>
              deletedSet.contains(p.duplicateMeal.id) ||
              deletedSet.contains(p.originalMeal.id));
          _isCleaningAll = false;
        });

        showAdminToast(
          context,
          message: strings.vaultDeduplicationAllCleanedSuccess(count),
          kind: AdminToastKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCleaningAll = false);
        showAdminToast(
          context,
          message: strings.vaultDeduplicationErrorCleanAllToast(e.toString()),
          kind: AdminToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final strings = AppStrings.of(context);

    final highConfidenceIds = _pairs
        .where((p) => p.similarity >= 0.95)
        .map((p) => p.duplicateMeal.id)
        .toSet();
    final uniqueDuplicatesCount = highConfidenceIds.length;

    return AdminDialogShell(
      icon: AdminIcons.cleanup,
      title: strings.vaultDeduplicationTitle,
      subtitle: strings.vaultDeduplicationSubtitle,
      tone: AdminDialogTone.warn,
      maxWidth: 720,
      scrollBody: false,
      actions: [
        AdminDialogButtons.ghost(
          p,
          label: strings.vaultDeduplicationClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (!_isLoading && _pairs.isNotEmpty && uniqueDuplicatesCount > 0)
          AdminDialogButtons.primary(
            p,
            label: strings
                .vaultDeduplicationCleanAllWithCount(uniqueDuplicatesCount),
            tone: AdminDialogTone.danger,
            icon: AdminIcons.cleanup,
            loading: _isCleaningAll,
            onPressed: _isCleaningAll
                ? null
                : () => _handleCleanAllRemaining(strings, p),
          ),
      ],
      child: _buildBody(p, strings),
    );
  }

  Widget _buildBody(AdminPalette p, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Switcher
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: false,
                label: Text(strings.vaultDeduplicationTabName,
                    style: adminText(size: 13, weight: FontWeight.w600)),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text(strings.vaultDeduplicationTabId,
                    style: adminText(size: 13, weight: FontWeight.w600)),
              ),
            ],
            selected: {_checkById},
            onSelectionChanged: (Set<bool> newSelection) {
              if (newSelection.isNotEmpty) {
                setState(() {
                  _checkById = newSelection.first;
                });
                _loadAndDetectDuplicates();
              }
            },
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: p.surface,
              selectedForegroundColor: p.onSolid(p.honeySolid),
              selectedBackgroundColor: p.honeySolid,
              foregroundColor: p.inkMuted,
            ),
          ),
        ),
        
        Expanded(child: _buildMainContent(p, strings)),
      ],
    );
  }

  Widget _buildMainContent(AdminPalette p, AppStrings strings) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5, color: p.honeySolid),
              const SizedBox(height: 16),
              Text(
                strings.vaultDeduplicationScanning,
                style: adminText(size: 14, weight: FontWeight.bold, color: p.ink),
              ),
              const SizedBox(height: 6),
              Text(
                strings.vaultDeduplicationScanningSubtitle,
                style: adminText(size: 12, color: p.inkMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AdminIcons.warning, size: 36, color: p.chiliSolid),
              const SizedBox(height: 12),
              Text(
                strings.vaultDeduplicationErrorTitle,
                style:
                    adminText(size: 14.5, weight: FontWeight.bold, color: p.ink),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: adminLatinText(size: 12, color: p.chiliInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AdminDialogButtons.primary(
                p,
                label: strings.vaultDeduplicationRetry,
                tone: AdminDialogTone.brand,
                icon: AdminIcons.refresh,
                onPressed: _loadAndDetectDuplicates,
              ),
            ],
          ),
        ),
      );
    }

    if (_pairs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.oliveSoft,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: p.oliveSolid.withValues(alpha: 0.28)),
                ),
                child: Icon(AdminIcons.success, size: 32, color: p.oliveInk),
              ),
              const SizedBox(height: 16),
              Text(
                strings.vaultDeduplicationEmptyTitle,
                style: adminText(size: 16, weight: FontWeight.bold, color: p.ink),
              ),
              const SizedBox(height: 6),
              Text(
                strings.vaultDeduplicationEmptySubtitle,
                style: adminText(size: 12.5, color: p.inkMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Header Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.honeySoft,
            borderRadius: BorderRadius.circular(AdminRadii.md),
            border: Border.all(color: p.honeySolid.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(AdminIcons.warning, size: 18, color: p.honeyInk),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.vaultDeduplicationPairsFound(_pairs.length),
                      style: adminText(
                        size: 13,
                        weight: FontWeight.bold,
                        color: p.honeyInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.vaultDeduplicationPairsFoundDesc,
                      style: adminText(size: 11.5, color: p.honeyInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Scrollable Pairs List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: _pairs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pair = _pairs[index];
              final isProcessing = _processingPairKeys.contains(pair.pairKey);
              return _buildPairCard(p, strings, pair, isProcessing);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPairCard(
    AdminPalette p,
    AppStrings strings,
    DuplicatePairCandidate pair,
    bool isProcessing,
  ) {
    final percent = (pair.similarity * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
        border: Border.all(color: p.borderStrong),
        boxShadow: [
          BoxShadow(
            color: p.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Match Score & Reason Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: percent >= 95 ? p.honeySoft : p.claySoft,
                  borderRadius: BorderRadius.circular(AdminRadii.pill),
                  border: Border.all(
                    color: (percent >= 95 ? p.honeySolid : p.claySolid)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AdminIcons.aiSparkle,
                      size: 12,
                      color: percent >= 95 ? p.honeyInk : p.onClaySoft,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      strings.vaultDeduplicationSimilarity(percent),
                      style: adminLatinText(
                        size: 11,
                        weight: FontWeight.bold,
                        color: percent >= 95 ? p.honeyInk : p.onClaySoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _checkById
                    ? strings.vaultDeduplicationExactNameDiffId
                    : (pair.similarity >= 0.999
                        ? strings.vaultDeduplicationExactMatch
                        : strings.vaultDeduplicationSimilarName),
                style: adminText(size: 11.5, color: p.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Side-by-side or stacked meal comparison
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 480;
              final mealAWidget = _buildMealItem(
                p,
                strings,
                meal: pair.originalMeal,
                isKeeper: true,
              );
              final mealBWidget = _buildMealItem(
                p,
                strings,
                meal: pair.duplicateMeal,
                isKeeper: false,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: mealAWidget),
                    const SizedBox(width: 10),
                    Expanded(child: mealBWidget),
                  ],
                );
              } else {
                return Column(
                  children: [
                    mealAWidget,
                    const SizedBox(height: 8),
                    mealBWidget,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Ignore Button
              Tooltip(
                message: strings.vaultDeduplicationIgnoreTooltip,
                child: OutlinedButton.icon(
                  onPressed: isProcessing || _isCleaningAll
                      ? null
                      : () => _handleIgnorePair(pair, strings),
                  icon: const Icon(AdminIcons.visibilityOff, size: 15),
                  label: Text(
                    strings.vaultDeduplicationIgnoreAction,
                    style: adminText(size: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.inkMuted,
                    side: BorderSide(color: p.borderStrong),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminRadii.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Delete Duplicate Button
              Tooltip(
                message: strings.vaultDeduplicationDeleteTooltip,
                child: FilledButton.icon(
                  onPressed: isProcessing || _isCleaningAll
                      ? null
                      : () => _handleDeletePair(pair, strings),
                  icon: isProcessing
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onSolid(p.chiliSolid),
                          ),
                        )
                      : const Icon(AdminIcons.delete, size: 15),
                  label: Text(
                    strings.vaultDeduplicationDeleteAction,
                    style: adminText(size: 12.5, weight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.chiliSolid,
                    foregroundColor: p.onSolid(p.chiliSolid),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminRadii.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealItem(
    AdminPalette p,
    AppStrings strings, {
    required CloudMeal meal,
    required bool isKeeper,
  }) {
    final accentBg = isKeeper ? p.oliveSoft : p.chiliSoft;
    final accentInk = isKeeper ? p.oliveInk : p.chiliInk;
    final accentSolid = isKeeper ? p.oliveSolid : p.chiliSolid;
    final formattedDate =
        '${meal.createdAt.year}-${meal.createdAt.month.toString().padLeft(2, '0')}-${meal.createdAt.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accentBg.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AdminRadii.md),
        border: Border.all(color: accentSolid.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isKeeper ? AdminIcons.verified : AdminIcons.delete,
                size: 14,
                color: accentInk,
              ),
              const SizedBox(width: 5),
              Text(
                isKeeper
                    ? strings.vaultDeduplicationOriginalBadge
                    : strings.vaultDeduplicationDuplicateBadge,
                style: adminText(
                  size: 11.5,
                  weight: FontWeight.bold,
                  color: accentInk,
                ),
              ),
              const Spacer(),
              if (meal.isStarterMeal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: p.honeySoft,
                    borderRadius: BorderRadius.circular(AdminRadii.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AdminIcons.starter, size: 10, color: p.honeyInk),
                      const SizedBox(width: 2),
                      Text(
                        strings.vaultDeduplicationStarterMeal,
                        style: adminText(size: 9.5, color: p.honeyInk),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meal.name,
            style: adminText(size: 13.5, weight: FontWeight.bold, color: p.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.vaultDeduplicationMealId(meal.id),
                  style: adminLatinText(size: 10.5, color: p.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message: strings.vaultDeduplicationCopyIdTooltip,
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: meal.id));
                    showAdminToast(
                      context,
                      message: strings.vaultDeduplicationCopiedIdToast,
                      kind: AdminToastKind.info,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(AdminIcons.copy, size: 12, color: p.inkMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strings.vaultDeduplicationAddedDate(formattedDate),
            style: adminLatinText(size: 10, color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}
