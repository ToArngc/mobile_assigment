import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Invokes one Edge Function through the shared Supabase client and
/// normalizes failures to a single [Exception] pattern used by every
/// repository: on a non-2xx response, the message is the function's own
/// `{ "error": "..." }` body (see supabase/functions/_shared/cors.ts's
/// errorResponse) when present, so the UI can eventually surface it
/// directly instead of a generic exception string.
Future<dynamic> invokeFunction(
  String functionName, {
  HttpMethod method = HttpMethod.get,
  Map<String, dynamic>? queryParameters,
  Object? body,
  Iterable<MultipartFile>? files,
}) async {
  try {
    final response = await SupabaseService.client.functions.invoke(
      functionName,
      method: method,
      queryParameters: queryParameters,
      body: body,
      files: files,
    );
    return response.data;
  } on FunctionException catch (e) {
    final details = e.details;
    final message = details is Map && details['error'] is String
        ? details['error'] as String
        : 'Request to $functionName failed (status ${e.status}).';
    throw Exception(message);
  }
}
