import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'pal_memory_controller.g.dart';

/// Pal's persistent memory for the "What Pal remembers" section. One-shot like
/// [palAgenda]; an unreachable backend degrades to an empty digest rather than
/// an error.
@riverpod
Future<PalMemoryDigest> palMemory(Ref ref) async {
  final pal = ref.watch(palServiceProvider);
  try {
    return await pal.memory();
  } catch (_) {
    return const PalMemoryDigest();
  }
}
