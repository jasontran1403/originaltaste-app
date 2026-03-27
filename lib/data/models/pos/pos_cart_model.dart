// lib/data/models/pos/pos_cart_model.dart

import 'package:originaltaste/data/models/pos/pos_product_model.dart';

// ═══════════════════════════════════════════════════════════════
// VariantGroupSelection — lưu lựa chọn variant + addon + unitWeights
// ═══════════════════════════════════════════════════════════════

class AddonItem {
  final int    ingredientId;
  final String ingredientName;
  final double baseAddonPrice;
  final double discountedAddonPrice;
  final int    quantity;

  const AddonItem({
    required this.ingredientId,
    required this.ingredientName,
    required this.baseAddonPrice,
    required this.discountedAddonPrice,
    required this.quantity,
  });

  AddonItem copyWith({int? quantity}) => AddonItem(
    ingredientId:        ingredientId,
    ingredientName:      ingredientName,
    baseAddonPrice:      baseAddonPrice,
    discountedAddonPrice: discountedAddonPrice,
    quantity:            quantity ?? this.quantity,
  );
}

class VariantGroupSelection {
  final int              variantId;
  final String           groupName;
  final bool             isAddonGroup;

  /// Map ingredientId → selectedCount (cho variant thường)
  final Map<int, int>    selectedIngredients;

  /// Addon items (chỉ dùng khi isAddonGroup = true)
  final List<AddonItem>? addonItems;

  /// Override định lượng từng unit, per ingredient.
  /// Key = ingredientId, Value = List<double> độ dài = selectedCount
  /// null / empty = dùng defaultDeductPerUnit × selectedCount
  final Map<int, List<double>> unitWeightsMap;

  const VariantGroupSelection({
    required this.variantId,
    required this.groupName,
    required this.isAddonGroup,
    required this.selectedIngredients,
    this.addonItems,
    this.unitWeightsMap = const {},
  });

  VariantGroupSelection copyWith({
    Map<int, List<double>>? unitWeightsMap,
  }) =>
      VariantGroupSelection(
        variantId:           variantId,
        groupName:           groupName,
        isAddonGroup:        isAddonGroup,
        selectedIngredients: selectedIngredients,
        addonItems:          addonItems,
        unitWeightsMap:      unitWeightsMap ?? this.unitWeightsMap,
      );

  /// Tổng định lượng của 1 ingredient (dùng để hiển thị tóm tắt)
  double totalWeightFor(int ingredientId, double defaultDeductPerUnit) {
    final weights = unitWeightsMap[ingredientId];
    if (weights != null && weights.isNotEmpty) {
      return weights.fold(0.0, (s, w) => s + w);
    }
    final count = selectedIngredients[ingredientId] ?? 0;
    return count * defaultDeductPerUnit;
  }
}

// ═══════════════════════════════════════════════════════════════
// CartItem
// ═══════════════════════════════════════════════════════════════

class CartItem {
  final PosProductModel        product;
  final PriceOption            selectedPrice;
  final List<VariantGroupSelection> variantSelections;
  final int                    quantity;
  final String?                note;

  const CartItem({
    required this.product,
    required this.selectedPrice,
    required this.variantSelections,
    required this.quantity,
    this.note,
  });

  double get addonPerUnit {
    double total = 0;
    for (final sel in variantSelections) {
      if (!sel.isAddonGroup || sel.addonItems == null) continue;
      for (final a in sel.addonItems!) {
        total += a.discountedAddonPrice * a.quantity;
      }
    }
    return total;
  }

  double get subtotal =>
      (selectedPrice.price + addonPerUnit) * quantity;

  CartItem copyWith({
    PriceOption?                  selectedPrice,
    int?                          quantity,
    String?                       note,
    List<VariantGroupSelection>?  variantSelections,
  }) =>
      CartItem(
        product:           product,
        selectedPrice:     selectedPrice ?? this.selectedPrice,
        variantSelections: variantSelections ?? this.variantSelections,
        quantity:          quantity ?? this.quantity,
        note:              note ?? this.note,
      );
}