import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'supabase_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseService _supabase = SupabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  bool get isAuthenticated => _supabase.isAuthenticated;
  String? get userId => _supabase.getUserId();
  String? get userEmail => _supabase.getUserEmail();
  String? get userName => _supabase.getUserName();
  String? get userAvatar => _supabase.getUserAvatar();

  Stream<dynamic> get authStateChanges => _supabase.authStateChanges;

  // ── Connexion avec Google ────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('[AUTH] Tentative de connexion Google...');
      
      // 1. Connexion Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[AUTH] Connexion annulée par l\'utilisateur');
        return false;
      }

      debugPrint('[AUTH] Utilisateur Google : ${googleUser.email}');

      // 2. Récupérer les tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        debugPrint('[AUTH] Tokens manquants');
        return false;
      }

      // 3. Connexion à Supabase avec les tokens Google
      final response = await _supabase.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        debugPrint('[AUTH] Échec de connexion Supabase');
        return false;
      }

      debugPrint('[AUTH] ✅ Connexion réussie : ${response.user!.email}');
      return true;

    } catch (e) {
      debugPrint('[AUTH] ❌ Erreur de connexion : $e');
      return false;
    }
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.signOut();
      debugPrint('[AUTH] ✅ Déconnexion réussie');
    } catch (e) {
      debugPrint('[AUTH] ❌ Erreur de déconnexion : $e');
    }
  }

  // ── Connexion silencieuse (auto-login) ───────────────────────────────────
  Future<bool> signInSilently() async {
    try {
      if (_supabase.isAuthenticated) {
        debugPrint('[AUTH] ✅ Déjà connecté');
        return true;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        debugPrint('[AUTH] Pas de session Google active');
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        return false;
      }

      final response = await _supabase.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        debugPrint('[AUTH] ✅ Connexion silencieuse réussie');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[AUTH] Connexion silencieuse échouée : $e');
      return false;
    }
  }
}
