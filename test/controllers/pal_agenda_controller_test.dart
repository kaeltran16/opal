import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/pal_agenda_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

/// Plays back one scripted response per `agenda` call: a [PalAgenda] is
/// returned, anything else is thrown. The last response repeats, so a retry
/// sees the same outcome.
class _ScriptedPal extends MockPalService {
  _ScriptedPal(this.script) : super(latency: Duration.zero);

  final List<Object> script;

  @override
  Future<PalAgenda> agenda() async {
    final next = script.length > 1 ? script.removeAt(0) : script.single;
    if (next is PalAgenda) return next;
    throw next;
  }
}

const _rent = PalProposal(
  id: 'rent',
  tag: 'Money',
  colorToken: 'money',
  icon: 'dollarsign.circle.fill',
  title: 'Hold \$40 for rent',
  body: "Say yes and Monday's rent is covered.",
  approveLabel: 'Hold \$40',
  approveIcon: 'checkmark',
  doneLabel: 'Held',
);

ProviderContainer _container(_ScriptedPal pal) {
  final c = ProviderContainer(overrides: [
    palServiceProvider.overrideWithValue(pal),
  ]);
  addTearDown(c.dispose);
  // hold a listener so the auto-dispose provider survives between reads.
  c.listen(palAgendaProvider, (_, _) {});
  return c;
}

void main() {
  test('a failed fetch is an error, not an empty agenda', () async {
    final c = _container(_ScriptedPal([Exception('unreachable')]));

    await expectLater(c.read(palAgendaProvider.future), throwsException);

    final state = c.read(palAgendaProvider);
    expect(state, isA<AsyncError<PalAgenda>>());
    expect(state.value, isNull);
  });

  test('a failed refresh is an error that still holds the earlier proposals', () async {
    final c = _container(_ScriptedPal([
      const PalAgenda(proposals: [_rent]),
      Exception('unreachable'),
    ]));
    expect((await c.read(palAgendaProvider.future)).proposals, [_rent]);

    c.invalidate(palAgendaProvider);
    await expectLater(c.read(palAgendaProvider.future), throwsException);

    final state = c.read(palAgendaProvider);
    expect(state.hasError, isTrue);
    expect(state.value?.proposals, [_rent]);
  });
}
