import 'dart:async';
import 'dart:math' show max;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'providers.dart';

part 'budget_envelopes_controller.g.dart';

/// Icon stem for envelopes created without a picked icon.
const String kDefaultEnvelopeIcon = 'creditcard';

const int kMaxEnvelopeNameLength = 40;

/// Area token stored with new envelopes; data only, like the seed.
const String _kEnvelopeColorToken = 'money';

/// Whether [name] (trimmed) already names an envelope, by [normalizeCategory].
bool isDuplicateEnvelope(List<BudgetEnvelope> envelopes, String name) {
  final key = normalizeCategory(name);
  return envelopes.any((e) => normalizeCategory(e.category) == key);
}

void _checkCap(double cap) {
  if (!cap.isFinite || cap <= 0) {
    throw ArgumentError.value(cap, 'cap', 'must be finite and above 0');
  }
}

/// Streams the budget envelopes (position order) and owns every envelope
/// write: the single source of truth the money providers and the envelope
/// editor read.
///
/// Writes read the current envelopes from the repository, not the streamed
/// [state], so back-to-back calls can't race the (async) stream tick.
/// Repository errors propagate to the caller.
///
/// No retry: a failing local query would fail again, and retrying holds the
/// screen on loading.
@Riverpod(retry: noRetry)
class BudgetEnvelopesController extends _$BudgetEnvelopesController {
  @override
  Stream<List<BudgetEnvelope>> build() {
    return ref.watch(budgetEnvelopeRepositoryProvider).watchEnvelopes();
  }

  Future<void> setCap(String id, double cap) async {
    _checkCap(cap);
    final repo = ref.read(budgetEnvelopeRepositoryProvider);
    final envelopes = await repo.getEnvelopes();
    final envelope = envelopes.where((e) => e.id == id).firstOrNull;
    if (envelope == null) throw StateError('setCap: no envelope $id');
    await repo.upsert(envelope.copyWith(cap: cap));
  }

  /// Appends a new envelope after the last one. Throws [ArgumentError] for a
  /// bad cap, or a category that is empty, too long or already an envelope.
  Future<void> add({
    required String category,
    required String icon,
    required double cap,
  }) async {
    _checkCap(cap);
    final name = category.trim();
    if (name.isEmpty || name.length > kMaxEnvelopeNameLength) {
      throw ArgumentError.value(category, 'category',
          'must be 1 to $kMaxEnvelopeNameLength characters');
    }
    final repo = ref.read(budgetEnvelopeRepositoryProvider);
    final envelopes = await repo.getEnvelopes();
    if (isDuplicateEnvelope(envelopes, name)) {
      throw ArgumentError.value(category, 'category', 'already an envelope');
    }
    final last = envelopes.map((e) => e.position).fold<int>(-1, max);
    await repo.upsert(BudgetEnvelope(
      id: const Uuid().v4(),
      category: name,
      cap: cap,
      icon: icon,
      colorToken: _kEnvelopeColorToken,
      position: last + 1,
    ));
  }

  Future<void> delete(String id) async {
    final repo = ref.read(budgetEnvelopeRepositoryProvider);
    await repo.deleteById(id);
    // reindex the survivors so positions stay gap-free and 0-based.
    await repo.reorder(await repo.getEnvelopes());
  }

  /// Moves the envelope at [oldIndex] to [newIndex], the post-removal target
  /// index `ReorderableListView.onReorderItem` supplies, and persists every
  /// position in one transaction.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final repo = ref.read(budgetEnvelopeRepositoryProvider);
    final list = await repo.getEnvelopes();
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    await repo.reorder(list);
  }

  /// Sets the cap of the envelope matching [category] under
  /// [normalizeCategory], or adds one with [icon].
  Future<void> applyCap(
    String category,
    double cap, {
    String icon = kDefaultEnvelopeIcon,
  }) async {
    final envelopes =
        await ref.read(budgetEnvelopeRepositoryProvider).getEnvelopes();
    final key = normalizeCategory(category);
    final match = envelopes
        .where((e) => normalizeCategory(e.category) == key)
        .firstOrNull;
    if (match == null) {
      await add(category: category, icon: icon, cap: cap);
    } else {
      await setCap(match.id, cap);
    }
  }
}
