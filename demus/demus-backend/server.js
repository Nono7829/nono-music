const express = require('express');
const cors = require('cors');
const { exec, spawn } = require('child_process');
const https = require('https');
const http = require('http');
const path = require('path');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// Chemin vers yt-dlp bundlé
const YT_DLP = path.join(__dirname, 'node_modules', 'youtube-dl-exec', 'bin', 'yt-dlp');

// ─────────────────────────────────────────────────────────────────────────────
// GET /search?q=PLK
// Retourne une liste de vidéos YouTube (NDJSON line-by-line depuis yt-dlp)
// ─────────────────────────────────────────────────────────────────────────────
app.get('/search', (req, res) => {
  const query = req.query.q;
  if (!query || !query.trim()) {
    return res.status(400).json({ error: 'Paramètre q manquant' });
  }
  console.log(`[SEARCH] Requête : "${query}"`);

  const command = [
    `"${YT_DLP}"`,
    `"ytsearch40:${query.replace(/"/g, '\\"')}"`,
    '--dump-json',
    '--no-playlist',
    '--flat-playlist',
    '--no-warnings',
    '--ignore-errors',
    '--extractor-args "youtube:skip=dash,hls"',
  ].join(' ');

  exec(command, { maxBuffer: 1024 * 1024 * 20 }, (error, stdout, stderr) => {
    if (stderr) console.warn('[SEARCH] stderr:', stderr.substring(0, 200));
    if (error && !stdout) {
      console.error('[SEARCH] Erreur:', error.message);
      return res.status(500).json({ error: 'Erreur yt-dlp', details: error.message });
    }

    const lines = stdout.split('\n').filter(l => l.trim());
    console.log(`[SEARCH] ${lines.length} lignes reçues`);

    const results = [];
    for (const line of lines) {
      try {
        const item = JSON.parse(line);
        const id = item.id ?? item.url ?? null;
        // Uniquement les vraies vidéos YouTube (11 caractères, pas de chaîne UCL...)
        if (!id || id.length !== 11) continue;
        // Filtrer les lives (durée nulle ou très longue)
        const duration = item.duration ?? 0;
        if (duration > 1800) continue; // max 30min = chanson, pas un concert

        results.push({
          id,
          title: item.title ?? item.fulltitle ?? 'Titre inconnu',
          artist: item.uploader ?? item.channel ?? item.artist ?? 'Artiste inconnu',
          duration,
          thumbnail: _bestThumbnail(item),
        });
      } catch (e) {
        // ligne JSON invalide, on ignore
      }
    }

    console.log(`[SEARCH] ${results.length} résultats valides`);
    return res.json({ results });
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /proxy/:videoId
//
// ARCHITECTURE PROXY :
//   Flutter → just_audio.setUrl('http://localhost:3000/proxy/ID')
//                   ↓
//   Node.js → yt-dlp obtient l'URL signée YouTube
//                   ↓
//   Node.js → proxifie l'audio vers Flutter avec support Range (seeking)
//
// Pourquoi proxy ? Les URL signées YouTube ont des headers spécifiques liés
// à l'IP de yt-dlp. Si Flutter essaie d'y accéder directement, YouTube refuse.
// En passant par localhost, c'est toujours Node.js qui accède à YouTube.
// ─────────────────────────────────────────────────────────────────────────────
app.get('/proxy/:videoId', async (req, res) => {
  const { videoId } = req.params;
  console.log(`[PROXY] Demande pour : ${videoId}`);

  // Étape 1 : obtenir l'URL de stream depuis yt-dlp
  let streamUrl;
  try {
    streamUrl = await getStreamUrl(videoId);
  } catch (err) {
    console.error('[PROXY] Erreur yt-dlp:', err.message);
    return res.status(500).json({ error: 'Impossible de récupérer le stream', details: err.message });
  }

  console.log(`[PROXY] URL obtenue, proxification en cours…`);

  // Étape 2 : proxifier avec support Range (pour le seeking dans just_audio)
  const rangHeader = req.headers['range'];
  const requestHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': '*/*',
    'Accept-Encoding': 'identity', // forcer non-compressé pour le streaming
    ...(rangHeader ? { 'Range': rangHeader } : {}),
  };

  const urlObj = new URL(streamUrl);
  const isHttps = urlObj.protocol === 'https:';
  const transport = isHttps ? https : http;

  const proxyReq = transport.get(streamUrl, { headers: requestHeaders }, (proxyRes) => {
    const statusCode = proxyRes.statusCode || 200;
    
    // Transmettre les headers importants
    const responseHeaders = {
      'Content-Type': proxyRes.headers['content-type'] || 'audio/mp4',
      'Accept-Ranges': 'bytes',
    };
    if (proxyRes.headers['content-length']) {
      responseHeaders['Content-Length'] = proxyRes.headers['content-length'];
    }
    if (proxyRes.headers['content-range']) {
      responseHeaders['Content-Range'] = proxyRes.headers['content-range'];
    }

    res.writeHead(statusCode, responseHeaders);
    proxyRes.pipe(res);
    
    req.on('close', () => proxyReq.destroy()); // Nettoyer si le client déconnecte
  });

  proxyReq.on('error', (err) => {
    console.error('[PROXY] Erreur de connexion YouTube:', err.message);
    if (!res.headersSent) {
      res.status(502).json({ error: 'Erreur de proxy', details: err.message });
    }
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /stream/:videoId  (rétro-compat : retourne l'URL brute)
// ─────────────────────────────────────────────────────────────────────────────
app.get('/stream/:videoId', async (req, res) => {
  const { videoId } = req.params;
  console.log(`[STREAM] Demande URL pour : ${videoId}`);
  try {
    const url = await getStreamUrl(videoId);
    return res.json({ url });
  } catch (err) {
    console.error('[STREAM] Erreur:', err.message);
    return res.status(500).json({ error: 'Impossible de récupérer le stream', details: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Utilitaire : obtenir l'URL de stream via yt-dlp (Promise)
// ─────────────────────────────────────────────────────────────────────────────
function getStreamUrl(videoId) {
  return new Promise((resolve, reject) => {
    const command = [
      `"${YT_DLP}"`,
      `"https://www.youtube.com/watch?v=${videoId}"`,
      '--get-url',
      '-f "bestaudio[ext=m4a]/bestaudio/best"',
      '--no-warnings',
      '--extractor-args "youtube:player-client=web,mweb,default"',
    ].join(' ');

    exec(command, { timeout: 20000 }, (error, stdout, stderr) => {
      if (error || !stdout.trim()) {
        return reject(new Error(stderr || error?.message || 'Aucune URL obtenue'));
      }
      resolve(stdout.trim().split('\n')[0]);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilitaire : meilleure miniature disponible
// ─────────────────────────────────────────────────────────────────────────────
function _bestThumbnail(item) {
  if (Array.isArray(item.thumbnails) && item.thumbnails.length > 0) {
    const sorted = item.thumbnails
      .filter(t => t && t.url)
      .sort((a, b) => (b.width ?? 0) - (a.width ?? 0));
    if (sorted.length > 0) return sorted[0].url;
  }
  if (item.thumbnail && typeof item.thumbnail === 'string') return item.thumbnail;
  if (item.id) return `https://i.ytimg.com/vi/${item.id}/hqdefault.jpg`;
  return '';
}

app.listen(PORT, () => {
  console.log(`✅ Nono Music backend démarré sur http://localhost:${PORT}`);
});