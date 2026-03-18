// lib/features/management/controller/management_tab_controller.dart
// Simple state để track tab hiện tại trong ManagementScreen

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ManagementTab { product, ingredient, category }

final managementTabProvider =
    StateProvider<ManagementTab>((ref) => ManagementTab.product);
