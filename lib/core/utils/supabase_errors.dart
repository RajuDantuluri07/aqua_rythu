import 'package:supabase_flutter/supabase_flutter.dart';

/// Classifies Supabase/PostgREST errors so the UI can show
/// meaningful messages instead of raw network failures.
enum SupabaseErrorKind {
  accessDenied,
  notFound,
  conflict,
  network,
  unknown,
}

class SupabaseErrorResult {
  final SupabaseErrorKind kind;
  final String message;
  final Object originalError;

  const SupabaseErrorResult({
    required this.kind,
    required this.message,
    required this.originalError,
  });
}

/// Inspects [error] and returns a typed result.
///
/// RLS violations from PostgREST arrive as PostgrestException with:
///   - code == '42501'  (PostgreSQL insufficient_privilege)
///   - code == 'PGRST301' (PostgREST permission denied)
/// On SELECT, RLS silently returns empty rows — no exception is thrown.
/// Callers should treat an unexpected empty result as a soft denial.
SupabaseErrorResult classifySupabaseError(Object error) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final msg = (error.message).toLowerCase();

    if (code == '42501' ||
        code == 'PGRST301' ||
        msg.contains('row-level security') ||
        msg.contains('insufficient_privilege') ||
        msg.contains('permission denied')) {
      return SupabaseErrorResult(
        kind: SupabaseErrorKind.accessDenied,
        message: 'You do not have permission to perform this action.',
        originalError: error,
      );
    }

    if (code == 'PGRST116' || msg.contains('no rows') || msg.contains('not found')) {
      return SupabaseErrorResult(
        kind: SupabaseErrorKind.notFound,
        message: 'The requested record was not found.',
        originalError: error,
      );
    }

    if (code == '23505' || msg.contains('duplicate') || msg.contains('unique')) {
      return SupabaseErrorResult(
        kind: SupabaseErrorKind.conflict,
        message: 'This record already exists.',
        originalError: error,
      );
    }
  }

  final msg = error.toString().toLowerCase();
  if (msg.contains('socketexception') ||
      msg.contains('network') ||
      msg.contains('timeout') ||
      msg.contains('connection')) {
    return SupabaseErrorResult(
      kind: SupabaseErrorKind.network,
      message: 'Network error. Please check your connection and try again.',
      originalError: error,
    );
  }

  return SupabaseErrorResult(
    kind: SupabaseErrorKind.unknown,
    message: 'An unexpected error occurred. Please try again.',
    originalError: error,
  );
}

/// Returns true if [error] is an RLS access-denied failure.
bool isRlsDenied(Object error) =>
    classifySupabaseError(error).kind == SupabaseErrorKind.accessDenied;

/// Human-readable message for any Supabase error.
String supabaseErrorMessage(Object error) =>
    classifySupabaseError(error).message;
