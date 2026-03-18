// lib/features/pos/models/pos_draft_models.dart

import 'package:originaltaste/data/models/pos/pos_product_model.dart';

/// Draft cho Variant Group hoặc Addon Group (dùng chung trong picker và form)
class VariantGroupDraft {
  final String  name;
  final int     minSelect;
  final int     maxSelect;
  final bool    allowRepeat;
  final List<int> ingredientIds;

  /// ingredientId → maxSelectableCount (số lần tối đa có thể chọn NL này)
  /// Đây chính là field maxSelectableCount trong PosVariantIngredient entity
  final Map<int, int>? ingredientQuantities;

  final int? existingId;

  const VariantGroupDraft({
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.allowRepeat,
    required this.ingredientIds,
    this.ingredientQuantities,
    this.existingId,
  });

  factory VariantGroupDraft.fromModel(PosVariantModel v) => VariantGroupDraft(
    name:         v.groupName,
    minSelect:    v.minSelect,
    maxSelect:    v.maxSelect,
    allowRepeat:  v.allowRepeat ?? false,
    ingredientIds: v.ingredients.map((i) => i.ingredientId).toList(),
    ingredientQuantities: {
      for (final i in v.ingredients)
        i.ingredientId: i.maxSelectableCount ?? 1,
    },
    existingId: v.id,
  );

  /// Body gửi lên API createVariant / updateVariant
  Map<String, dynamic> toBody({required int productId}) => {
    'productId':   productId,
    'groupName':   name,
    'minSelect':   minSelect,
    'maxSelect':   maxSelect,
    'allowRepeat': allowRepeat,
    'isAddonGroup': false,
    'ingredients': ingredientIds.map((id) => {
      'ingredientId':       id,
      // maxSelectableCount = số lần khách có thể chọn NL này
      'maxSelectableCount': ingredientQuantities?[id] ?? 1,
      // stockDeductPerUnit mặc định 1 — trừ kho 1 lần mỗi khi chọn
      'stockDeductPerUnit': 1,
    }).toList(),
  };
}


/// Draft riêng cho Addon Group (vì addon có cấu hình khác: min=0, max lớn, không allowRepeat)
class AddonGroupDraft {
  final String  name;
  final List<int> ingredientIds;
  final Map<int, int>? ingredientQuantities;
  final int? existingId;

  const AddonGroupDraft({
    required this.name,
    required this.ingredientIds,
    this.ingredientQuantities,
    this.existingId,
  });

  factory AddonGroupDraft.fromVariant(VariantGroupDraft v) => AddonGroupDraft(
    name:                 v.name,
    ingredientIds:        v.ingredientIds,
    ingredientQuantities: v.ingredientQuantities,
    existingId:           v.existingId,
  );

  factory AddonGroupDraft.fromModel(PosVariantModel v) => AddonGroupDraft(
    name:          v.groupName,
    ingredientIds: v.ingredients.map((i) => i.ingredientId).toList(),
    ingredientQuantities: {
      for (final i in v.ingredients)
        i.ingredientId: i.maxSelectableCount ?? 1,
    },
    existingId: v.id,
  );

  Map<String, dynamic> toBody({required int productId}) => {
    'productId':    productId,
    'groupName':    name,
    'minSelect':    0,
    'maxSelect':    ingredientIds.length,
    'allowRepeat':  false,
    'isAddonGroup': true,
    'ingredients': ingredientIds.map((id) => {
      'ingredientId':       id,
      'maxSelectableCount': ingredientQuantities?[id] ?? 1,
      'stockDeductPerUnit': 1,
    }).toList(),
  };
}
