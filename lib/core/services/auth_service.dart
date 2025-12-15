import 'supabase_service.dart';

class AuthService {
  final SupabaseService _supabase = SupabaseService();
  static String? pendingEstablishmentId;
  static bool pendingReservationAction = false;

  Future<Map<String, dynamic>?> getCurrentUserProfile({String? userId}) async {
    final targetId = userId ?? _supabase.currentUserId;
    if (targetId == null) return null;

    final response = await _supabase.client
        .from('users')
        .select()
        .eq('id', targetId)
        .single();

    return response;
  }

  Future<String?> getUserRole({String? userId}) async {
    final profile = await getCurrentUserProfile(userId: userId);
    return profile?['user_type'];
  }

  Future<void> signOut() async {
    pendingEstablishmentId = null; // Clear pending navigation
    await _supabase.client.auth.signOut();
  }
}
