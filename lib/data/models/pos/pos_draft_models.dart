// lib/data/models/pos/pos_draft_models.dart
//
// THAY ĐỔI: thêm ingredientDeductMap vào VariantGroupDraft

import 'package:originaltaste/data/models/pos/pos_product_model.dart';

// ── VariantGroupDraft ─────────────────────────────────────────────────────────

class VariantGroupDraft {
  final String           name;
  final num              minSelect;
  final num              maxSelect;
  final bool             allowRepeat;
  final List<int>        ingredientIds;
  final Map<int, num>?   ingredientQuantities;

  /// Định lượng mặc định (stockDeductPerUnit) cho từng ingredient.
  /// Key = ingredientId, Value = deductPerUnit (VD: 0.2 cho 200g/miếng).
  /// null = tất cả dùng 1.0.
  final Map<int, double>? ingredientDeductMap;

  final int? existingId;

  const VariantGroupDraft({
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.allowRepeat,
    required this.ingredientIds,
    this.ingredientQuantities,
    this.ingredientDeductMap,
    this.existingId,
  });

  /// Build body gửi lên server khi tạo / update variant
  Map<String, dynamic> toBody({required int productId}) {
    return {
      'productId':    productId,
      'groupName':    name,
      'minSelect':    minSelect,
      'maxSelect':    maxSelect,
      'allowRepeat':  allowRepeat,
      'isAddonGroup': false,
      'ingredients':  ingredientIds.map((id) {
        final qty         = ingredientQuantities?[id] ?? 1;
        final deductPerUnit = ingredientDeductMap?[id] ?? 1.0;
        return {
          'ingredientId':       id,
          'maxSelectableCount': qty,
          'stockDeductPerUnit': deductPerUnit,
        };
      }).toList(),
    };
  }

  /// Tạo từ PosVariantModel (khi edit)
  static VariantGroupDraft fromModel(PosVariantModel v) {
    return VariantGroupDraft(
      name:         v.groupName,
      minSelect:    v.minSelect,
      maxSelect:    v.maxSelect,
      allowRepeat:  v.allowRepeat,
      ingredientIds: v.ingredients.map((vi) => vi.ingredientId).toList(),
      ingredientQuantities: {
        for (final vi in v.ingredients)
          vi.ingredientId: vi.maxSelectableCount ?? 1,
      },
      ingredientDeductMap: {
        for (final vi in v.ingredients)
          vi.ingredientId: vi.stockDeductPerUnit,
      },
      existingId: v.id,
    );
  }
}

// ── AddonGroupDraft ───────────────────────────────────────────────────────────

class AddonGroupDraft {
  final String    name;
  final List<int> ingredientIds;

  /// Định lượng mặc định cho addon ingredients (stockDeductPerUnit)
  /// Key = ingredientId, Value = deductPerUnit
  /// null = tất cả dùng 1.0
  final Map<int, double>? ingredientDeductMap;

  final int?      existingId;

  const AddonGroupDraft({
    required this.name,
    required this.ingredientIds,
    this.ingredientDeductMap,  // ← THÊM
    this.existingId,
  });

  Map<String, dynamic> toBody({required int productId}) {
    return {
      'productId':    productId,
      'groupName':    name,
      'minSelect':    0,
      'maxSelect':    999,
      'allowRepeat':  false,
      'isAddonGroup': true,
      'ingredients':  ingredientIds.map((id) {
        final deductPerUnit = ingredientDeductMap?[id] ?? 1.0;  // ← SỬ DỤNG
        return {
          'ingredientId':       id,
          'maxSelectableCount': 1,
          'stockDeductPerUnit': deductPerUnit,  // ← GỬI LÊN SERVER
        };
      }).toList(),
    };
  }

  static AddonGroupDraft fromVariant(VariantGroupDraft v) => AddonGroupDraft(
    name:         v.name,
    ingredientIds: v.ingredientIds,
    ingredientDeductMap: v.ingredientDeductMap,  // ← COPY
    existingId:   v.existingId,
  );

  static AddonGroupDraft fromModel(PosVariantModel v) => AddonGroupDraft(
    name:         v.groupName,
    ingredientIds: v.ingredients.map((vi) => vi.ingredientId).toList(),
    ingredientDeductMap: {
      for (final vi in v.ingredients)
        vi.ingredientId: vi.stockDeductPerUnit,  // ← LOAD TỪ MODEL
    },
    existingId:   v.id,
  );
}
