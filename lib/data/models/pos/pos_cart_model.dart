// lib/data/models/pos/pos_cart_model.dart

import 'package:originaltaste/data/models/pos/pos_product_model.dart';

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
    ingredientId: ingredientId,
    ingredientName: ingredientName,
    baseAddonPrice: baseAddonPrice,
    discountedAddonPrice: discountedAddonPrice,
    quantity: quantity ?? this.quantity,
  );
}

class VariantGroupSelection {
  final int variantId;
  final String groupName;
  final bool isAddonGroup;

  final Map<int, int> selectedIngredients;
  final List<AddonItem>? addonItems;
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
        variantId: variantId,
        groupName: groupName,
        isAddonGroup: isAddonGroup,
        selectedIngredients: selectedIngredients,
        addonItems: addonItems,
        unitWeightsMap: unitWeightsMap ?? this.unitWeightsMap,
      );

  double totalWeightFor(int ingredientId, double defaultDeductPerUnit) {
    final weights = unitWeightsMap[ingredientId];
    if (weights != null && weights.isNotEmpty) {
      return weights.fold(0.0, (s, w) => s + w);
    }
    final count = selectedIngredients[ingredientId] ?? 0;
    return count * defaultDeductPerUnit;
  }
}

// ==================== CARTITEM - ĐÃ SỬA THEO BACKEND ====================

class CartItem {
  final PosProductModel product;
  final PriceOption selectedPrice;
  final List<VariantGroupSelection> variantSelections;
  final int quantity;
  final String? note;

  /// GIÁ GHI ĐÈ CHO ĐƠN APP (quan trọng nhất)
  final double? overriddenUnitPrice;

  const CartItem({
    required this.product,
    required this.selectedPrice,
    required this.variantSelections,
    required this.quantity,
    this.note,
    this.overriddenUnitPrice,
  });

  /// Giá thực tế sẽ gửi lên server
  double get finalUnitPrice {
    if (overriddenUnitPrice != null && overriddenUnitPrice! > 0) {
      return overriddenUnitPrice!;
    }
    return selectedPrice.price;
  }

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

  double get subtotal => (finalUnitPrice + addonPerUnit) * quantity;

  CartItem copyWith({
    PriceOption? selectedPrice,
    int? quantity,
    String? note,
    List<VariantGroupSelection>? variantSelections,
    double? overriddenUnitPrice,
  }) =>
      CartItem(
        product: product,
        selectedPrice: selectedPrice ?? this.selectedPrice,
        variantSelections: variantSelections ?? this.variantSelections,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
        overriddenUnitPrice: overriddenUnitPrice ?? this.overriddenUnitPrice,
      );
}