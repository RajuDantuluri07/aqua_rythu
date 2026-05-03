import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_rythu/features/auth/auth_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockRef extends Mock implements Ref {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockRef mockRef;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockRef = MockRef();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentSession).thenReturn(null);
  });

  group('AuthNotifier tests', () {
    test('initial state and checkSession', () async {
      final notifier = AuthNotifier(mockRef, supabaseClient: mockSupabase);

      // Allow checkSession future to complete
      await Future.delayed(Duration.zero);

      expect(notifier.state.isCheckingSession, false);
      expect(notifier.state.isAuthenticated, false);
    });

    test('signIn error path updates state with error message', () async {
      final notifier = AuthNotifier(mockRef, supabaseClient: mockSupabase);

      when(() => mockAuth.signInWithPassword(email: 'test@example.com', password: 'password'))
          .thenThrow(const AuthException('Invalid login credentials'));

      final result = await notifier.signIn('test@example.com', 'password');

      expect(result, false);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.isAuthenticated, false);
      expect(notifier.state.errorMessage, 'Incorrect email or password. Please try again.');
    });
  });
}
