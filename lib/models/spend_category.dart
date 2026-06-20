/// The canonical spend categories — the single source of truth shared by the
/// budget envelopes, the insights breakdown, and (going forward) the entry
/// category picker. Keeping one list means an entry's category lines up with an
/// envelope and the "spent this month" total can't diverge between screens.
///
/// The seed [budgetEnvelopes] use exactly these names; a self-consistency test
/// guards the two from drifting apart.
const kSpendCategories = <String>[
  'Food & Drink',
  'Groceries',
  'Bills & Utilities',
  'Shopping',
  'Transport',
  'Entertainment',
  'Health',
];

/// Match key for a category: trimmed and lower-cased. The budgets and insights
/// breakdowns both bucket through this so they agree on what matches what.
String normalizeCategory(String? category) =>
    (category ?? '').trim().toLowerCase();
