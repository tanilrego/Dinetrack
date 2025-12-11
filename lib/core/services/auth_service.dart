import 'supabase_service.dart';

class AuthService {
  final SupabaseService _supabase = SupabaseService();
  static String? pendingEstablishmentId;

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final userId = _supabase.currentUserId;
    if (userId == null) return null;

    final response = await _supabase.client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return response;
  }

  Future<String?> getUserRole() async {
    final profile = await getCurrentUserProfile();
    return profile?['user_type'];
  }

  Future<void> signOut() async {
    pendingEstablishmentId = null; // Clear pending navigation
    await _supabase.client.auth.signOut();
  }
}
