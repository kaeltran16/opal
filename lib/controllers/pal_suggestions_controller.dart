import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'pal_suggestions_controller.g.dart';

/// Pal-generated quick-pick chips for [surface] (the `/suggestions` seam).
/// One-shot, family-keyed by surface. An unreachable backend / timeout /
/// malformed payload degrades to an empty list, so each surface renders its
/// own static fallback (mirrors [palAgenda]'s graceful-degradation boundary).
@riverpod
Future<List<PalSuggestion>> palSuggestions(Ref ref, SuggestionSurface surface) async {
  final pal = ref.watch(palServiceProvider);
  try {
    return await pal.suggestions(surface);
  } catch (e) {
    // The empty list is the contract, but it is also what a healthy backend
    // returns when it has nothing to say — so without this a persistently
    // failing seam is indistinguishable from a quiet one. Debug-only: the
    // graceful degradation itself is unchanged.
    debugPrint('palSuggestions(${surface.name}) failed: $e');
    return const [];
  }
}
