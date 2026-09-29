import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/widgets/admin_toast.dart';
import 'models/cloud_meal.dart';
import 'vault_admin_repository.dart';

final backgroundUploadProvider = NotifierProvider<BackgroundUploadNotifier, bool>(() {
  return BackgroundUploadNotifier();
});

class BackgroundUploadNotifier extends Notifier<bool> {
  @override
  bool build() => false; // returns true if any upload is in progress

  Future<void> startUpload({
    required CloudMeal meal,
    required Uint8List? imageBytes,
    required String? imageName,
    required bool isStaging,
    required bool isEdit,
  }) async {
    state = true;

    final progress = AdminToast.loading(
      message: 'جارٍ رفع "${meal.name}" في الخلفية',
      subtitle: 'يمكنك متابعة العمل، سنُشعرك عند الانتهاء',
    );

    try {
      final repo = ref.read(vaultAdminRepositoryProvider);
      String? imageUrl = meal.imageUrl;

      if (imageBytes != null && imageName != null) {
        // Enforce a hard timeout so it doesn't spin forever if Storage is not set up
        final uploadedUrl = await repo.uploadMealImage(imageBytes, imageName).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('انتهى وقت الاتصال (تأكد من تفعيل Storage في Firebase)'),
        );
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        }
      }

      final mealToSave = meal.copyWith(imageUrl: imageUrl);

      if (isStaging) {
        await repo.approveStagingMeal(mealToSave);
      } else if (!isEdit) {
        if (await repo.mealExists(mealToSave.name)) {
          throw Exception('هذه الأكلة موجودة بالفعل في الخزنة العامة');
        }
        await repo.addVaultMeal(mealToSave);
      } else {
        await repo.updateVaultMeal(mealToSave);
      }

      progress.resolve(
        message: 'تم حفظ "${meal.name}" في الخزنة',
        subtitle: isStaging
            ? 'تم اعتماد المقترح المرفوع'
            : (isEdit ? 'تم تحديث بيانات الأكلة' : 'أُضيفت أكلة جديدة'),
        kind: AdminToastKind.success,
      );
    } catch (e) {
      progress.resolve(
        message: 'فشل حفظ "${meal.name}"',
        subtitle: e.toString(),
        kind: AdminToastKind.error,
      );
    } finally {
      state = false;
    }
  }
}
