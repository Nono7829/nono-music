const express = require('express');
const cors = require('cors');
const { exec } = require('child_process');
const path = require('path');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// Chemin vers yt-dlp (dans node_modules ou système)
const YT_DLP = path.join(__dirname, 'node_modules', 'youtube-dl-exec', 'bin', 'yt-dlp');

// ─────────────────────────────────────────
// GET /search?q=PLK
// ─────────────────────────────────────────
app.get('/search', (req, res) => {
  const query = req.query.q;

  if (!query || query.trim() === '') {
    return res.status(400).json({ error: 'Paramètre q manquant' });
  }

  console.log(`[SEARCH] Requête reçue : "${query}"`);

  // On demande 15 résultats depuis YouTube Music
  const command = [
    `"${YT_DLP}"`,
    `"ytsearch15:${query.replace(/"/g, '\\"')}"`,
    '--dump-json',
    '--no-playlist',
    '--flat-playlist',
    '--no-warnings',
    '--ignore-errors',
    '--extractor-args "youtube:skip=dash,hls"',
  ].join(' ');

  console.log(`[SEARCH] Commande : ${command}`);

  exec(command, { maxBuffer: 1024 * 1024 * 10 }, (error, stdout, stderr) => {
    if (stderr) {
      console.warn(`[SEARCH] stderr : ${stderr.substring(0, 300)}`);
    }

    if (error && !stdout) {
      console.error(`[SEARCH] Erreur exec : ${error.message}`);
      return res.status(500).json({ error: 'Erreur yt-dlp', details: error.message });
    }

    // yt-dlp retourne un JSON par ligne (NDJSON)
    const lines = stdout.split('\n').filter(line => line.trim().length > 0);
    console.log(`[SEARCH] Lignes JSON reçues : ${lines.length}`);

    const results = [];

    for (const line of lines) {
      try {
        const item = JSON.parse(line);

        // Extraction sécurisée des champs
        const id         = item.id          ?? item.url ?? null;
        const title      = item.title       ?? item.fulltitle ?? 'Titre inconnu';
        const artist     = item.uploader    ?? item.channel ?? item.artist ?? 'Artiste inconnu';
        const duration   = item.duration    ?? 0;
        const thumbnail  = _bestThumbnail(item);

        if (!id) continue; // on ignore les entrées sans ID

        results.push({ id, title, artist, duration, thumbnail });
      } catch (parseErr) {
        console.warn(`[SEARCH] Ligne JSON invalide : ${line.substring(0, 80)}`);
      }
    }

    console.log(`[SEARCH] ${results.length} résultats valides envoyés`);
    return res.json({ results });
  });
});

// ─────────────────────────────────────────
// GET /stream/:videoId  (pour lecture future)
// ─────────────────────────────────────────
app.get('/stream/:videoId', (req, res) => {
  const { videoId } = req.params;
  console.log(`[STREAM] Demande stream pour : ${videoId}`);

  const command = [
    `"${YT_DLP}"`,
    `"https://www.youtube.com/watch?v=${videoId}"`,
    '--get-url',
    '-f "bestaudio[ext=m4a]/bestaudio/best"',
    '--no-warnings',
  ].join(' ');

  exec(command, (error, stdout, stderr) => {
    if (error || !stdout.trim()) {
      console.error(`[STREAM] Erreur : ${error?.message}`);
      return res.status(500).json({ error: 'Impossible de récupérer le stream' });
    }

    const streamUrl = stdout.trim().split('\n')[0];
    console.log(`[STREAM] URL obtenue pour ${videoId}`);
    return res.json({ url: streamUrl });
  });
});

// ─────────────────────────────────────────
// Utilitaire : meilleure miniature disponible
// ─────────────────────────────────────────
function _bestThumbnail(item) {
  // 1. Tableau thumbnails trié par résolution
  if (Array.isArray(item.thumbnails) && item.thumbnails.length > 0) {
    const sorted = item.thumbnails
      .filter(t => t && t.url)
      .sort((a, b) => (b.width ?? 0) - (a.width ?? 0));
    if (sorted.length > 0) return sorted[0].url;
  }

  // 2. Champ thumbnail simple
  if (item.thumbnail && typeof item.thumbnail === 'string') {
    return item.thumbnail;
  }

  // 3. Fallback construit depuis l'ID
  if (item.id) {
    return `https://i.ytimg.com/vi/${item.id}/hqdefault.jpg`;
  }

  return '';
}

app.listen(PORT, () => {
  console.log(`✅ Nono Music backend démarré sur http://localhost:${PORT}`);
});