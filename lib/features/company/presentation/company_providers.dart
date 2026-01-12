import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'company_controller.dart';
import 'company_state.dart';

/// Empresa activa del usuario autenticado.
/// Lee el uid desde authStateProvider dentro del controller.
final companyControllerProvider =
    AsyncNotifierProvider<CompanyController, CompanyState>(CompanyController.new);
