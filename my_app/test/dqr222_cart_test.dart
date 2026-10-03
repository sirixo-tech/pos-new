import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/customer_display/dqr222_customer_display_service_io.dart';

void main() {
  late List<List<String>> writes;
  setUp(() {
    resetDqr222ForTest();
    writes = [];
    dqr222TestTransport = (
      findPort: () async => 'COM1',
      writeCommands: (commands) async => writes.add(List.of(commands)),
      readFileInfo: () async => '',
    );
  });
  tearDown(resetDqr222ForTest);

  Map<String, dynamic> cart(int count) => {
    'items': List.generate(count, (i) => {
      'name': 'Item $i', 'quantity': 1, 'price': 10,
    }),
    'total': count * 10,
  };

  test('idle refresh preserves cart while adding a third item', () async {
    await showDqr222Cart(cart(2));
    final before = writes.length;
    await showDqr222HomeIfIdle();
    expect(writes.length, before);
    await showDqr222Cart(cart(3));
    expect(writes.last.any((c) => c.startsWith('billjson**')), isTrue);
    expect(writes.last.join(), contains('Item 2'));
  });

  test('explicit cart clear does not restore the previous bill', () async {
    await showDqr222Cart(cart(2));
    writes.clear();
    await showDqr222Cart({'items': <dynamic>[]});
    await showDqr222HomeIfIdle();
    expect(writes.expand((batch) => batch).any((c) => c.startsWith('billjson**')), isFalse);
  });

  test('rapid clear and replace survives an obsolete write failure', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var first = true;
    dqr222TestTransport = (
      findPort: () async => 'COM1',
      readFileInfo: () async => '',
      writeCommands: (commands) async {
        writes.add(List.of(commands));
        if (first) {
          first = false;
          started.complete();
          await release.future;
          throw StateError('Old USB write failed');
        }
      },
    );
    final pending = showDqr222Cart(cart(5));
    await started.future;
    await showDqr222Cart({'items': <dynamic>[]});
    await showDqr222Cart({
      'items': [{'name': 'New item only', 'quantity': 1, 'price': 65}],
      'total': 65,
    });
    release.complete();
    await pending;
    expect(writes.last.join(), contains('New item only'));
    expect(writes.last.join(), isNot(contains('Item 4')));
  });

  test('second item is sent after a slow first-item write', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var first = true;
    dqr222TestTransport = (
      findPort: () async => 'COM1',
      readFileInfo: () async => '',
      writeCommands: (commands) async {
        writes.add(List.of(commands));
        if (first) {
          first = false;
          started.complete();
          await release.future;
        }
      },
    );
    final pending = showDqr222Cart(cart(1));
    await started.future;
    await showDqr222Cart(cart(2));
    release.complete();
    await pending;
    expect(writes.last.join(), contains('Item 1'));
  });

  test('latest two-item cart retries a transient USB failure', () async {
    var failures = 0;
    dqr222TestTransport = (
      findPort: () async => 'COM1',
      readFileInfo: () async => '',
      writeCommands: (commands) async {
        if (failures++ == 0) throw StateError('USB busy');
        writes.add(List.of(commands));
      },
    );
    await showDqr222Cart(cart(2));
    expect(writes.last.join(), contains('Item 1'));
  });
}
