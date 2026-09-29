import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/cloud_meal.dart';
import '../../data/background_upload_provider.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';
import 'admin_toast.dart';
import 'image_drop/image_drop.dart';

class AddMealDialog extends ConsumerStatefulWidget {
  final CloudMeal? initialMeal;
  final bool isStaging;

  const AddMealDialog({super.key, this.initialMeal, this.isStaging = false});

  @override
  ConsumerState<AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends ConsumerState<AddMealDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _shortNameController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _notesController;

  late String _category;
  late String _proteinType;
  late String _carbsType;
  late bool _isFridaySpecial;
  late bool _isBudgetFriendly;
  late bool _isStarterMeal;

  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _isDraggingImage = false;
  void Function()? _detachImageDrop;

  final _categories = const [
    {'key': 'tabeekh', 'label': 'طبيخ وخضار'},
    {'key': 'casserole', 'label': 'صواني وطواجن فرن'},
    {'key': 'dry_sandwich', 'label': 'نواشف وساندوتشات'},
    {'key': 'popular', 'label': 'أكل شعبي'},
    {'key': 'seafood', 'label': 'أسماك وبحريات'},
    {'key': 'soup_stew', 'label': 'شوربات'},
    {'key': 'vegetarian', 'label': 'نباتي'},
  ];

  final _proteins = const [
    {'key': 'chicken', 'label': 'فراخ / دواجن'},
    {'key': 'beef', 'label': 'لحوم حمراء'},
    {'key': 'fish', 'label': 'أسماك'},
    {'key': 'meatless', 'label': 'بدون لحوم (أرديحي)'},
    {'key': 'dairy', 'label': 'بيض وألبان'},
    {'key': 'other', 'label': 'أخرى'},
  ];

  final _carbs = const [
    {'key': 'rice', 'label': 'أرز'},
    {'key': 'pasta', 'label': 'مكرونة'},
    {'key': 'bread', 'label': 'عيش / خبز'},
    {'key': 'potato', 'label': 'بطاطس'},
    {'key': 'grains', 'label': 'حبوب وفريك'},
    {'key': 'none', 'label': 'بدون نشويات'},
  ];

  @override
  void initState() {
    super.initState();
    final meal = widget.initialMeal;
    _nameController = TextEditingController(text: meal?.name ?? '');
    _shortNameController = TextEditingController(text: meal?.shortName ?? '');
    _imageUrlController = TextEditingController(text: meal?.imageUrl ?? '');
    _prepTimeController = TextEditingController(
      text: (meal?.prepTimeMinutes ?? 30).toString(),
    );
    _notesController = TextEditingController(text: meal?.notes ?? '');

    _category = meal?.category ?? 'tabeekh';
    _proteinType = meal?.proteinType ?? 'chicken';
    _carbsType = meal?.carbsType ?? 'rice';
    _isFridaySpecial = meal?.isFridaySpecial ?? false;
    _isBudgetFriendly = meal?.isBudgetFriendly ?? false;
    _isStarterMeal = meal?.isStarterMeal ?? false;

    _detachImageDrop = watchImageDrop(
      onImage: (bytes, name) => setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = name;
        _imageUrlController.clear();
      }),
      onNonImage: (name) => AdminToast.show(
        message: 'الملف المسحوب ليس صورة',
        subtitle: name,
        kind: AdminToastKind.warning,
      ),
      onDrag: (active) {
        if (mounted) setState(() => _isDraggingImage = active);
      },
    );
  }

  @override
  void dispose() {
    _detachImageDrop?.call();
    _nameController.dispose();
    _shortNameController.dispose();
    _imageUrlController.dispose();
    _prepTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 92,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = file.name;
        // A fresh local photo replaces any link, so the preview always shows
        // exactly what will be saved.
        _imageUrlController.clear();
      });
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageName = null;
      _imageUrlController.clear();
    });
  }

  String get _imageCaption {
    if (_isDraggingImage) return 'أفلت الصورة لتضعها هنا';
    if (_pickedImageBytes != null) {
      return 'صورة جاهزة من جهازك — هتترفع مع الحفظ';
    }
    if (_imageUrlController.text.trim().isNotEmpty) {
      return 'الصورة الحالية من الرابط، اضغط ✕ للإزالة';
    }
    return imageDropSupported
        ? 'اسحب صورة من جهازك وأفلتها هنا، أو ارفعها من الزر'
        : 'لا توجد صورة مختارة لهذه الأكلة';
  }

  void _saveMeal() {
    if (!_formKey.currentState!.validate()) return;

    final mealToSave = CloudMeal(
      id: widget.initialMeal?.id ?? '',
      name: _nameController.text.trim(),
      shortName: _shortNameController.text.trim().isEmpty
          ? null
          : _shortNameController.text.trim(),
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      category: _category,
      proteinType: _proteinType,
      carbsType: _carbsType,
      prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()) ?? 30,
      isFridaySpecial: _isFridaySpecial,
      isBudgetFriendly: _isBudgetFriendly,
      isStarterMeal: _isStarterMeal,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.initialMeal?.createdAt ?? DateTime.now(),
      proposedBy: widget.initialMeal?.proposedBy,
      status: 'approved',
    );

    // Start background upload — it reports progress through the toast stack
    ref
        .read(backgroundUploadProvider.notifier)
        .startUpload(
          meal: mealToSave,
          imageBytes: _pickedImageBytes,
          imageName: _pickedImageName,
          isStaging: widget.isStaging,
          isEdit: widget.initialMeal != null,
        );

    // Close dialog immediately without waiting
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final isEdit = widget.initialMeal != null;

    return AdminDialogShell(
      icon: isEdit ? AdminIcons.edit : AdminIcons.add,
      tone: AdminDialogTone.brand,
      title: isEdit ? 'تعديل أكلة في الخزنة' : 'إضافة أكلة جديدة',
      subtitle: isEdit
          ? 'حدّث بيانات الأكلة ثم احفظ التعديلات'
          : 'املأ البيانات التالية لإضافة الأكلة للخزنة',
      maxWidth: 620,
      actions: [
        AdminDialogButtons.ghost(
          p,
          label: 'إلغاء',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AdminDialogButtons.primary(
          p,
          label: isEdit ? 'حفظ التعديلات' : 'إضافة إلى الخزنة',
          tone: AdminDialogTone.brand,
          icon: AdminIcons.verified,
          onPressed: _saveMeal,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminSectionLabel(
              icon: AdminIcons.basicInfo,
              text: 'البيانات الأساسية',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              style: adminText(color: p.ink),
              decoration: adminFieldDeco(
                p,
                label: 'اسم الأكلة (الكامل) *',
                hint: 'مثال: كبدة إسكندراني بالثوم والفلفل الحامي وعيش بلدي',
                icon: AdminIcons.meal,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'لازم تكتب اسم الأكلة' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shortNameController,
              style: adminText(color: p.ink),
              decoration: adminFieldDeco(
                p,
                label: 'اختصار (الاسم القصير)',
                hint: 'مثال: كبدة إسكندراني',
                icon: AdminIcons.edit,
              ),
            ),
            const SizedBox(height: 22),
            const AdminSectionLabel(
              icon: AdminIcons.settings,
              text: 'التصنيف والتفاصيل',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    dropdownColor: p.surface,
                    borderRadius: BorderRadius.circular(AdminRadii.md),
                    icon: Icon(AdminIcons.expand, color: p.inkMuted),
                    style: adminText(color: p.ink),
                    decoration: adminFieldDeco(p, label: 'تصنيف الأكلة'),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['key'],
                            child: Text(
                              c['label']!,
                              style: adminText(size: 14, color: p.ink),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _proteinType,
                    isExpanded: true,
                    dropdownColor: p.surface,
                    borderRadius: BorderRadius.circular(AdminRadii.md),
                    icon: Icon(AdminIcons.expand, color: p.inkMuted),
                    style: adminText(color: p.ink),
                    decoration: adminFieldDeco(p, label: 'نوع البروتين'),
                    items: _proteins
                        .map(
                          (x) => DropdownMenuItem(
                            value: x['key'],
                            child: Text(
                              x['label']!,
                              style: adminText(size: 14, color: p.ink),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _proteinType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _carbsType,
                    isExpanded: true,
                    dropdownColor: p.surface,
                    borderRadius: BorderRadius.circular(AdminRadii.md),
                    icon: Icon(AdminIcons.expand, color: p.inkMuted),
                    style: adminText(color: p.ink),
                    decoration: adminFieldDeco(p, label: 'نوع النشويات'),
                    items: _carbs
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['key'],
                            child: Text(
                              c['label']!,
                              style: adminText(size: 14, color: p.ink),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _carbsType = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    keyboardType: TextInputType.number,
                    style: adminText(color: p.ink),
                    decoration: adminFieldDeco(
                      p,
                      label: 'وقت التحضير (دقيقة)',
                      icon: AdminIcons.time,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const AdminSectionLabel(icon: AdminIcons.tags, text: 'الوسوم'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FlagCheck(
                    p: p,
                    value: _isFridaySpecial,
                    label: 'أكلة جمعة / عزومات',
                    icon: AdminIcons.friday,
                    accent: p.nileInk,
                    accentBg: p.nileSoft,
                    onChanged: (v) => setState(() => _isFridaySpecial = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FlagCheck(
                    p: p,
                    value: _isBudgetFriendly,
                    label: 'أكلة اقتصادية / توفير',
                    icon: AdminIcons.money,
                    accent: p.oliveInk,
                    accentBg: p.oliveSoft,
                    onChanged: (v) => setState(() => _isBudgetFriendly = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: p.panel(
                color: _isStarterMeal ? p.honeySoft : p.surfaceAlt,
                radius: AdminRadii.md,
                borderColor: _isStarterMeal ? p.honeySolid : p.border,
              ),
              child: Row(
                children: [
                  Icon(
                    AdminIcons.starter,
                    color: _isStarterMeal ? p.honeyInk : p.inkFaint,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'وجبة أساسية للمستخدمين الجدد (Starter Pack)',
                          style: adminText(
                            weight: FontWeight.bold,
                            size: 13.5,
                            color: _isStarterMeal ? p.honeyInk : p.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'تُنزل هذه الوجبة تلقائياً عند تثبيت التطبيق لأول مرة لأي مستخدم جديد',
                          style: adminText(
                            size: 11.5,
                            color: p.inkMuted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch(
                    value: _isStarterMeal,
                    activeThumbColor: p.honeySolid,
                    activeTrackColor: p.honeySolid.withValues(alpha: 0.35),
                    onChanged: (v) => setState(() => _isStarterMeal = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const AdminSectionLabel(
              icon: AdminIcons.photo,
              text: 'صورة الأكلة',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: p.panel(color: p.surfaceAlt, radius: AdminRadii.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _ImagePreview(
                        p: p,
                        bytes: _pickedImageBytes,
                        url: _imageUrlController.text.trim(),
                        dragging: _isDraggingImage,
                        onRemove: _removeImage,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: p.claySolid,
                                side: BorderSide(color: p.borderStrong),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AdminRadii.sm,
                                  ),
                                ),
                              ),
                              icon: const Icon(AdminIcons.upload, size: 18),
                              label: Text(
                                _pickedImageBytes != null
                                    ? 'تغيير الصورة المرفوعة'
                                    : 'رفع صورة من الجهاز',
                                style: adminText(
                                  size: 13,
                                  weight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _imageCaption,
                              style: adminText(size: 11.5, color: p.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _imageUrlController,
                    textDirection: TextDirection.ltr,
                    style: adminText(size: 13, color: p.ink),
                    decoration: adminFieldDeco(
                      p,
                      label: 'أو ضع رابط صورة مباشر (URL)',
                      icon: AdminIcons.link,
                    ),
                    onChanged: (v) => setState(() {
                      // The link and a local photo are one image: typing a
                      // link drops the pending upload.
                      if (v.trim().isNotEmpty && _pickedImageBytes != null) {
                        _pickedImageBytes = null;
                        _pickedImageName = null;
                      }
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const AdminSectionLabel(icon: AdminIcons.notes, text: 'ملاحظات'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: adminText(color: p.ink),
              decoration: adminFieldDeco(
                p,
                label: 'ملاحظات أو مقترحات تقديم (اختياري)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail of the image that will actually be saved — local upload first,
/// then the link — with an inline remove affordance and a drop highlight while
/// a file is being dragged over the page.
class _ImagePreview extends StatelessWidget {
  final AdminPalette p;
  final Uint8List? bytes;
  final String url;
  final bool dragging;
  final VoidCallback onRemove;

  const _ImagePreview({
    required this.p,
    required this.bytes,
    required this.url,
    required this.dragging,
    required this.onRemove,
  });

  static const double _size = 88;

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null || url.isNotEmpty;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(AdminRadii.sm),
              border: Border.all(
                color: dragging ? p.claySolid : p.borderStrong,
                width: dragging ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AdminRadii.sm - 1),
              child: _content(),
            ),
          ),
          if (dragging)
            Positioned.fill(
              child: Material(
                color: p.claySolid.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(AdminRadii.sm),
                child: const Center(
                  child: Icon(AdminIcons.upload, size: 24, color: Colors.white),
                ),
              ),
            ),
          if (hasImage && !dragging)
            Positioned(
              top: 5,
              right: 5,
              child: Tooltip(
                message: 'إزالة الصورة',
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: p.chiliSolid,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 1.5),
                    ),
                    child: const Icon(
                      AdminIcons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.cover);
    }
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(),
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() =>
      Center(child: Icon(AdminIcons.image, size: 26, color: p.inkFaint));
}

/// Checkbox card used for the "Friday" and "budget" tags.
class _FlagCheck extends StatelessWidget {
  final AdminPalette p;
  final bool value;
  final String label;
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final ValueChanged<bool> onChanged;

  const _FlagCheck({
    required this.p,
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AdminRadii.md),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: p.panel(
            color: value ? accentBg : p.surfaceAlt,
            radius: AdminRadii.md,
            borderColor: value ? accent.withValues(alpha: 0.45) : p.border,
          ),
          child: Row(
            children: [
              Icon(
                value ? AdminIcons.checkbox : AdminIcons.checkboxOff,
                size: 20,
                color: value ? accent : p.inkFaint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: adminText(
                    size: 13,
                    weight: value ? FontWeight.bold : FontWeight.w500,
                    color: value ? accent : p.ink,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: value ? accent : p.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
