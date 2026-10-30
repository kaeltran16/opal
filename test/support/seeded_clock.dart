import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart' show goldenClock;

/// [testWidgets] run at [goldenClock]'s 09:30, for tests that read today's
/// seeded meals. The seeder places them "so far today" against `clock.now()`,
/// so on a wall clock before the first meal (07:50) they land on yesterday and
/// the test finds none.
void testWidgetsSeeded(String description, WidgetTesterCallback callback) =>
    testWidgets(description, (tester) => withClock(goldenClock, () => callback(tester)));
