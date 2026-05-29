import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailtether_app/services/offline_incident_queue.dart';

void main() {
  // Setup SharedPreferences mock values before each test run
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineIncidentQueue', () {
    test('enqueues failed incidents successfully and increments count',
        () async {
      expect(await OfflineIncidentQueue.count(), 0);

      final incident = {
        'type': 'lost_disoriented',
        'severity': 'warning',
        'description': 'Hiker drifted 55m off-trail bearing NE',
        'latitude': -29.0456,
        'longitude': 29.4123,
      };

      await OfflineIncidentQueue.enqueue(incident);
      expect(await OfflineIncidentQueue.count(), 1);

      final secondIncident = {
        'type': 'medical',
        'severity': 'critical',
        'description': 'Hiker reporting minor knee sprain',
        'latitude': -29.0489,
        'longitude': 29.4145,
      };

      await OfflineIncidentQueue.enqueue(secondIncident);
      expect(await OfflineIncidentQueue.count(), 2);
    });

    test('drains all queued incidents and clears the backing store', () async {
      final incident = {'id': 1, 'type': 'alert'};
      await OfflineIncidentQueue.enqueue(incident);
      expect(await OfflineIncidentQueue.count(), 1);

      final items = await OfflineIncidentQueue.drainAll();
      expect(items.length, 1);
      expect(items[0]['id'], 1);

      // The queue should now be empty
      expect(await OfflineIncidentQueue.count(), 0);
      final emptyItems = await OfflineIncidentQueue.drainAll();
      expect(emptyItems, isEmpty);
    });

    test('re-enqueues items to the front on sync/upload failure', () async {
      final first = {'id': 1};
      final second = {'id': 2};

      await OfflineIncidentQueue.enqueue(second);
      final drained = await OfflineIncidentQueue.drainAll();

      // Simulate a sync failure and re-enqueue both first and second
      await OfflineIncidentQueue.reenqueue([first, ...drained]);

      expect(await OfflineIncidentQueue.count(), 2);

      final finalDrained = await OfflineIncidentQueue.drainAll();
      expect(finalDrained.length, 2);
      expect(finalDrained[0]['id'], 1); // first should be at the front
      expect(finalDrained[1]['id'], 2);
    });

    test('caps the queue size at 100 items to prevent memory exhaustion',
        () async {
      expect(await OfflineIncidentQueue.count(), 0);

      // Enqueue 105 mock incidents
      for (int i = 1; i <= 105; i++) {
        await OfflineIncidentQueue.enqueue({'id': i});
      }

      // The queue size must be capped at 100
      expect(await OfflineIncidentQueue.count(), 100);

      final items = await OfflineIncidentQueue.drainAll();
      expect(items.length, 100);

      // The oldest 5 items (ids 1 to 5) should have been pruned
      expect(items.first['id'], 6);
      expect(items.last['id'], 105);
    });
  });
}
