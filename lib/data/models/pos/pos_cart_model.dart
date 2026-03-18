// lib/data/models/pos/pos_cart_model.dart

import 'pos_product_model.dart';

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

  double get subtotal => discountedAddonPrice * quantity;
}

class VariantGroupSelection {
  final int    variantId;
  final String groupName;
  final bool   isAddonGroup;
  final Map<int, int>   selectedIngredients; // ingredientId → count
  final List<AddonItem>? addonItems;

  const VariantGroupSelection({
    required this.variantId,
    required this.groupName,
    this.isAddonGroup = false,
    required this.selectedIngredients,
    this.addonItems,
  });
}

class CartItem {
  final PosProductModel             product;
  final PriceOption                 selectedPrice;
  final List<VariantGroupSelection> variantSelections;
  final int     quantity;
  final String? note;

  const CartItem({
    required this.product,
    required this.selectedPrice,
    this.variantSelections = const [],
    required this.quantity,
    this.note,
  });

  double get addonPerUnit {
    double t = 0;
    for (final s in variantSelections) {
      if (!s.isAddonGroup || s.addonItems == null) continue;
      for (final a in s.addonItems!) t += a.subtotal;
    }
    return t;
  }

  double get addonTotal => addonPerUnit * quantity;
  double get subtotal   => (selectedPrice.price + addonPerUnit) * quantity;

  // ← THÊM selectedPrice vào copyWith
  CartItem copyWith({
    PriceOption? selectedPrice,
    int?         quantity,
    String?      note,
  }) => CartItem(
    product:           product,
    selectedPrice:     selectedPrice ?? this.selectedPrice,  // ← THÊM
    variantSelections: variantSelections,
    quantity:          quantity ?? this.quantity,
    note:              note ?? this.note,
  );
}
