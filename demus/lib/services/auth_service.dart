import 'dart:io' show Platform, HttpServer, HttpRequest, InternetAddress, ContentType;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseService _supabase = SupabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '988799160042-p5rkmd8qlgfgaohm5nrdr0823r92o7si.apps.googleusercontent.com',
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
      
      // 💻 VÉRIFICATION PC (Astuce du serveur local)
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        debugPrint('[AUTH] Lancement de la connexion via le navigateur (Mode PC)...');

        // 1. Démarrer un mini-serveur local pour intercepter le retour de Google
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3005);
        const redirectUrl = 'http://localhost:3005/callback';

        // 2. Ouvrir le navigateur en demandant à Supabase de revenir sur le port 3005
        await _supabase.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
        );

        // 3. Attendre que le navigateur nous renvoie la réponse
        await for (HttpRequest request in server) {
          if (request.uri.path == '/callback') {
            final fullUri = Uri.parse('http://localhost:3005${request.uri.toString()}');
            
            // 4. Afficher une belle page au lieu du "Cannot /GET"
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.html
              ..write(
                '<html><body style="background-color:#0A0A0A;color:white;text-align:center;padding-top:100px;font-family:sans-serif;">'
                '<h1>✅ Connexion reussie !</h1>'
                '<p style="color:grey;">Vous pouvez fermer cet onglet et retourner sur Nono Music.</p>'
                '</body></html>'
              );
            await request.response.close();
            await server.close(force: true); // Fermer le serveur

            // 5. Donner le lien intercepté à Supabase pour valider la connexion Flutter !
            await _supabase.client.auth.getSessionFromUrl(fullUri);
            debugPrint('[AUTH] ✅ Connexion PC réussie');
            return true;
          }
        }
        return false; 
      }

      // 📱 SUR MOBILE : Fonctionnement classique avec google_sign_in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[AUTH] Connexion annulée par l\'utilisateur');
        return false;
      }

      debugPrint('[AUTH] Utilisateur Google : ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        debugPrint('[AUTH] Tokens Google manquants');
        return false;
      }

      final response = await _supabase.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        debugPrint('[AUTH] ✅ Connexion Supabase réussie');
        return true;
      }
      return false;

    } catch (e) {
      debugPrint('[AUTH] ❌ Erreur : $e');
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

      // Le mode silencieux est désactivé sur PC car il requiert le navigateur,
      // on vérifie seulement si la session Supabase est toujours active.
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
         return _supabase.isAuthenticated;
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