// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_airship/otel_airship.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_airship-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('push records audience + device types + region', () async {
    await tracedAirship<String>(
      operation: 'push',
      region: 'eu',
      invoke: () async => const AirshipCallResult(
        value: 'ok',
        result: AirshipResult(
          pushIds: 1,
          operationId: 'op-1',
          audience: 'segment',
          deviceTypes: 'ios,android,web',
          region: 'eu',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('airship push')!);
    expect(a['airship.audience'], 'segment');
    expect(a['airship.device_types'], 'ios,android,web');
    expect(a['airship.region'], 'eu');
    expect(a['airship.operation.id'], 'op-1');
  });

  test('failed schedule sets span error', () async {
    await tracedAirship<String>(
      operation: 'schedules.create',
      invoke: () async => const AirshipCallResult(
        value: 'ok',
        result: AirshipResult(scheduleStatus: 'failed'),
      ),
    );
    expect(
      spans.findSpanByName('airship schedules.create')!.status,
      SpanStatusCode.Error,
    );
  });

  test('journey execute records key + named user', () async {
    await tracedAirship<String>(
      operation: 'journeys.execute',
      invoke: () async => const AirshipCallResult(
        value: 'ok',
        result: AirshipResult(journeyKey: 'jr-1', namedUser: 'u-1'),
      ),
    );
    final a = attrsOf(spans.findSpanByName('airship journeys.execute')!);
    expect(a['airship.journey.key'], 'jr-1');
    expect(a['airship.named_user'], 'u-1');
  });

  test('suppression skips spans', () async {
    await runWithoutAirshipInstrumentationAsync(() async {
      await tracedAirship<String>(
        operation: 'channels.list',
        invoke: () async => const AirshipCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('airship '), isEmpty);
  });
}
