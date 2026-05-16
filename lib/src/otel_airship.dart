// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_airship_suppression.dart';

const _tracerName = 'dartastic_otel_libs_airship';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class AirshipResult {
  const AirshipResult({
    this.pushIds,
    this.operationId,
    this.audience,
    this.deviceTypes,
    this.scheduleStatus,
    this.journeyKey,
    this.namedUser,
    this.region,
    this.requestId,
    this.statusCode,
  });

  /// `push_ids.length` from a /api/push response.
  final int? pushIds;

  /// `operation_id` for tracing across attribution windows.
  final String? operationId;

  /// `all` / `triggered` / `segment` / `tag` / `named_user` /
  /// `device_token` — audience-targeting shape.
  final String? audience;

  /// Comma-joined device types (`ios`, `android`, `amazon`, `web`,
  /// `email`, `sms`, `mms`, `open::ott`).
  final String? deviceTypes;

  /// `scheduled` / `paused` / `canceled` / `completed` / `failed`
  /// for scheduled pushes.
  final String? scheduleStatus;

  /// Journey key when sent via a journey.
  final String? journeyKey;

  /// `named_user` id when targeting one.
  final String? namedUser;

  /// `us` / `eu` — Airship region (data residency).
  final String? region;

  /// `X-UA-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class AirshipCallResult<T> {
  const AirshipCallResult({required this.value, this.result});
  final T value;
  final AirshipResult? result;
}

/// Wraps an Airship API call in a CLIENT span. [operation] is one of
/// `push`, `push.validate`, `schedules.create`, `schedules.list`,
/// `schedules.update`, `schedules.cancel`, `journeys.list`,
/// `journeys.execute`, `named_users.set`, `named_users.unset`,
/// `named_users.list`, `segments.create`, `segments.list`,
/// `channels.lookup`, `channels.list`, `channels.uninstall`,
/// `email.send`, `sms.send`, `in_app.send`.
Future<T> tracedAirship<T>({
  required String operation,
  required Future<AirshipCallResult<T>> Function() invoke,
  String? region,
}) async {
  if (airshipInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'airship',
    'rpc.method': operation,
    'airship.operation': operation,
  };
  if (region != null) m['airship.region'] = region;

  final span = _tracer().startSpan(
    'airship $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.pushIds != null) {
        extras.add(OTel.attributeInt(
          'airship.push_ids',
          r.result!.pushIds!,
        ));
      }
      if (r.result!.operationId != null) {
        extras.add(OTel.attributeString(
          'airship.operation.id',
          r.result!.operationId!,
        ));
      }
      if (r.result!.audience != null) {
        extras.add(OTel.attributeString(
          'airship.audience',
          r.result!.audience!,
        ));
      }
      if (r.result!.deviceTypes != null) {
        extras.add(OTel.attributeString(
          'airship.device_types',
          r.result!.deviceTypes!,
        ));
      }
      if (r.result!.scheduleStatus != null) {
        extras.add(OTel.attributeString(
          'airship.schedule.status',
          r.result!.scheduleStatus!,
        ));
        if (r.result!.scheduleStatus == 'failed') {
          span.setStatus(
            SpanStatusCode.Error,
            'Airship schedule failed',
          );
        }
      }
      if (r.result!.journeyKey != null) {
        extras.add(OTel.attributeString(
          'airship.journey.key',
          r.result!.journeyKey!,
        ));
      }
      if (r.result!.namedUser != null) {
        extras.add(OTel.attributeString(
          'airship.named_user',
          r.result!.namedUser!,
        ));
      }
      if (r.result!.region != null) {
        extras.add(OTel.attributeString(
          'airship.region',
          r.result!.region!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'airship.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Airship HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
