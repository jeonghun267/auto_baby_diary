import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PlanType { free, premium, family }

final currentPlanProvider = Provider<PlanType>((ref) => PlanType.free);
final isPremiumProvider =
    Provider<bool>((ref) => true); // School project: all features enabled
