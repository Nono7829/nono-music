# Prompt v2 (ultra-précis) à coller dans Claude

Tu es **Principal Engineer Flutter + Backend + Infra**, missionné pour livrer un correctif **production-grade** d’une app musicale multi-plateforme.

## Objectif business
Je veux que la lecture musicale fonctionne de façon stable sur **iOS, macOS, Linux, Windows, Web, Android**, sans crash, avec une UX de recherche unifiée (sans switch manuel Spotify/YouTube).

## Problèmes à corriger (priorité stricte)
1) **Crash / perte de connexion pendant lecture audio**.
2) **Téléchargement instable / non fiable**.
3) **Recherche mal orchestrée** : je ne veux plus de boutons Spotify/YouTube dans l’UI; je veux une seule page qui choisit automatiquement la meilleure source selon le type de contenu.
4) **Timeout 45s côté logique applicative** à supprimer (Render ne doit pas couper à 45s; j’ai déjà un bot de ping).

## Logs réels à prendre comme source de vérité
Tu dois partir de ces indices concrets (et les traiter explicitement dans ton diagnostic):
- `just_audio_windows ... channel sent a message ... on a non-platform thread`
- `Item error: Le texte associé à ce code d’erreur est introuvable`
- `[AUDIO] timeout chargement ...`
- `[AUDIO] playSong error: Loading interrupted`
- `Broadcast playback event error ... BufferingProgress`
- `Lost connection to device`

## Hypothèse principale à valider
Le plugin audio Windows (`just_audio_windows`) envoie des events hors thread plateforme et déclenche des erreurs natives/interop => instabilité player, erreurs de buffering, puis crash/VM detach.
Tu dois **prouver ou réfuter** cette hypothèse par inspection du code + reproduction + instrumentation.

## Exigences techniques non négociables
- Tu peux refactorer l’architecture, pas juste patcher.
- Tu dois implémenter un **AudioEngine cross-platform** avec adaptation par plateforme.
- Tu dois ajouter **guard rails anti-crash** partout sur le cycle player.
- Tu dois supprimer le **toggle Spotify/YouTube** dans la recherche et le remplacer par un routage automatique.
- Tu dois livrer des tests + métriques + runbook déploiement.

---

## Plan imposé (à exécuter dans cet ordre)

### 1) Diagnostic prouvé et reproductible
- Cartographie des flux:
  - `search -> select result -> resolve source -> prewarm -> load -> play`
  - téléchargement `enqueue -> fetch -> write -> verify -> index`
- Reproduction scriptée par plateforme (au minimum Windows + Android + Web; puis iOS/macOS/Linux).
- Ajouter logs structurés avec `correlationId` par tentative de lecture.
- Identifier causes racines avec preuves (stack traces, traces async, erreurs natives plugin).

### 2) Stabiliser la lecture audio (P0)
- Introduire une couche `AudioEngine` + `PlatformAudioAdapter`.
- Implémenter machine d’état stricte: `idle -> preparing -> buffering -> ready -> playing -> ended | failed`.
- Interdire les transitions invalides (ex: `play` si `preparing` non terminé).
- Encapsuler `setAudioSource/load/play` avec:
  - timeout paramétrable par étape (pas de hardcoded 45s global)
  - retry exponentiel borné
  - cancellation token
  - fallback source (stream alternatif ou local cache)
- Capturer toutes exceptions et retourner des erreurs typées vers l’UI (jamais crash process).
- Sur Windows:
  - auditer compatibilité version `just_audio` / `just_audio_windows`
  - corriger thread-affinity côté plugin utilisé ou appliquer workaround côté app (dispatcher main/platform thread, sérialisation des events)
  - ajouter feature-flag `audio.windows.safe_mode`

### 3) Fiabiliser téléchargement (P1)
- Pipeline explicite: `queued -> starting -> downloading -> validating -> completed | failed | canceled`.
- Resume/retry + backoff + cleanup fichiers partiels.
- Vérification intégrité (taille/CRC/hash selon coût).
- Échec visible utilisateur + détails techniques en logs.

### 4) Recherche unifiée sans boutons Spotify/YouTube (P1)
- **Supprimer les boutons/switchs Spotify/YouTube de la page recherche**.
- Une seule barre de recherche + sections (Titres, Artistes, Albums, Clips).
- Routing automatique:
  - audio song => priorité Spotify
  - clip/vidéo => priorité YouTube Music
- Déduplication inter-sources (titre/artiste/durée fuzzy).
- Contrat DTO unifié pour l’UI.

### 5) Timeouts & Render (P0 infra)
- Supprimer toute logique hardcodée `45s` dans backend/services/jobs.
- Remplacer par timeouts granulaires (`connect/read/total`) via config.
- Longs traitements en async/background queue si nécessaire.
- Documenter précisément variables Render et valeurs recommandées.

### 6) Qualité et validation
- Tests obligatoires:
  - unitaires: state machine player, resolver source, scoring recherche
  - intégration: lecture stream + fallback + download pipeline
  - e2e: rechercher -> lancer lecture -> changement piste -> reprise après erreur
- Matrice de validation par plateforme: iOS/macOS/Linux/Windows/Web/Android.
- SLO cible:
  - crash-free sessions >= 99.9%
  - succès démarrage lecture >= 99%
  - latence recherche p95 < 2s (hors cold start)

### 7) Livrables obligatoires dans ta réponse
Réponds en 6 blocs:
1. Diagnostic prouvé
2. Diff architecture (avant/après)
3. Patch détaillé par fichier
4. Résultats de tests (commandes + sorties)
5. Plan de déploiement progressif + rollback
6. Risques restants et next steps

## Style de réponse attendu
- Pas de blabla, seulement de l’exécutable.
- Si une dépendance/plugin est en cause, propose:
  1) fix immédiat (court terme)
  2) alternative robuste (moyen terme)
  3) option de migration complète (long terme)
- Chaque affirmation doit être appuyée par une preuve (log, test, code).

Commence maintenant, et priorise d’abord la stabilisation lecture (crash) puis l’UX recherche unifiée.
