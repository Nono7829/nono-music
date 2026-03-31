const express = require('express');
const cors    = require('cors');
const { exec } = require('child_process');
const https   = require('https');
const http    = require('http');
const path    = require('path');

const app  = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

const YT_DLP = path.join(
  __dirname, 'node_modules', 'youtube-dl-exec', 'bin', 'yt-dlp'
);

// ─── Cache des URLs de stream ────────────────────────────────────────────────
// Les URLs signées YouTube sont valides ~6h. On les garde 4h pour être safe.
const STREAM_CACHE     = new Map(); // videoId → { url, expiresAt }
const CACHE_TTL_MS     = 4 * 60 * 60 * 1000; // 4 heures
// Requêtes en cours (dedup : si deux requêtes arrivent en même temps pour le
// même videoId, on attend la même Promise au lieu de lancer deux yt-dlp)
const PENDING_FETCHES  = new Map(); // videoId → Promise<string>

// ─── GET /search?q=... ───────────────────────────────────────────────────────
app.get('/search', (req, res) => {
  const query = (req.query.q || '').trim();
  if (!query) return res.status(400).json({ error: 'Paramètre q manquant' });

  console.log(`[SEARCH] "${query}"`);

  const safeQuery = query.replace(/"/g, '\\"');
  const cmd = [
    `"${YT_DLP}"`,
    `"ytsearch40:${safeQuery}"`,
    '--dump-json',
    '--flat-playlist',
    '--no-warnings',
    '--ignore-errors',
  ].join(' ');

  exec(cmd, { maxBuffer: 1024 * 1024 * 20, timeout: 30000 }, (err, stdout, stderr) => {
    if (stderr) console.warn('[SEARCH] stderr:', stderr.substring(0, 200));
    if (err && !stdout) {
      console.error('[SEARCH] exec error:', err.message);
      return res.status(500).json({ error: 'yt-dlp failed', details: err.message });
    }

    const results = [];
    for (const line of stdout.split('\n').filter(Boolean)) {
      try {
        const item = JSON.parse(line);
        const id = item.id ?? null;
        if (!id || id.length !== 11) continue;           // pas une vidéo YT
        const dur = item.duration ?? 0;
        if (dur > 1800) continue;                        // > 30 min → concert/live
        results.push({
          id,
          title:     item.title     ?? 'Titre inconnu',
          artist:    item.uploader  ?? item.channel ?? 'Artiste inconnu',
          duration:  dur,
          thumbnail: bestThumb(item),
        });
      } catch (_) {}
    }

    console.log(`[SEARCH] → ${results.length} résultats`);
    return res.json({ results });
  });
});

// ─── GET /proxy/:videoId ─────────────────────────────────────────────────────
// just_audio pointe ici. Node proxifie l'audio avec support Range (seeking).
app.get('/proxy/:videoId', async (req, res) => {
  const { videoId } = req.params;
  console.log(`[PROXY] ${videoId}`);

  let streamUrl;
  try {
    streamUrl = await getStreamUrl(videoId);
  } catch (err) {
    console.error('[PROXY] getStreamUrl error:', err.message);
    return res.status(500).json({ error: 'Cannot get stream', details: err.message });
  }

  const rangeHeader = req.headers['range'];
  const reqHeaders  = {
    'User-Agent':      'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Accept':          '*/*',
    'Accept-Encoding': 'identity',
    ...(rangeHeader ? { Range: rangeHeader } : {}),
  };

  const transport = streamUrl.startsWith('https') ? https : http;

  const proxyReq = transport.get(streamUrl, { headers: reqHeaders }, (proxyRes) => {
    const status = proxyRes.statusCode ?? 200;

    // Si YouTube retourne 403/410, vider le cache et signaler l'erreur
    if (status === 403 || status === 410) {
      STREAM_CACHE.delete(videoId);
      console.warn(`[PROXY] ${status} from YouTube, cache invalidé`);
      if (!res.headersSent) {
        res.status(status).json({ error: `YouTube returned ${status}` });
      }
      return;
    }

    const resHeaders = {
      'Content-Type':  proxyRes.headers['content-type'] || 'audio/mp4',
      'Accept-Ranges': 'bytes',
    };
    if (proxyRes.headers['content-length']) {
      resHeaders['Content-Length'] = proxyRes.headers['content-length'];
    }
    if (proxyRes.headers['content-range']) {
      resHeaders['Content-Range'] = proxyRes.headers['content-range'];
    }

    res.writeHead(status, resHeaders);
    proxyRes.pipe(res);
    req.on('close', () => { try { proxyReq.destroy(); } catch (_) {} });
  });

  proxyReq.on('error', (err) => {
    console.error('[PROXY] pipe error:', err.message);
    if (!res.headersSent) res.status(502).json({ error: 'Proxy error', details: err.message });
  });
});

// ─── GET /stream/:videoId ────────────────────────────────────────────────────
// Retourne l'URL brute (pour le téléchargement via Dio).
app.get('/stream/:videoId', async (req, res) => {
  const { videoId } = req.params;
  console.log(`[STREAM] ${videoId}`);
  try {
    const url = await getStreamUrl(videoId);
    return res.json({ url });
  } catch (err) {
    return res.status(500).json({ error: 'Cannot get stream', details: err.message });
  }
});

// ─── Utilitaire : URL de stream avec CACHE ───────────────────────────────────
function getStreamUrl(videoId) {
  // 1. Cache valide → retour immédiat (0 ms de latence)
  const cached = STREAM_CACHE.get(videoId);
  if (cached && Date.now() < cached.expiresAt) {
    console.log(`[CACHE] hit → ${videoId}`);
    return Promise.resolve(cached.url);
  }

  // 2. Requête déjà en cours → on attend la même Promise
  if (PENDING_FETCHES.has(videoId)) {
    console.log(`[CACHE] pending → ${videoId}`);
    return PENDING_FETCHES.get(videoId);
  }

  // 3. Nouveau fetch
  console.log(`[CACHE] miss → fetch yt-dlp pour ${videoId}`);
  const promise = new Promise((resolve, reject) => {
    const cmd = [
      `"${YT_DLP}"`,
      `"https://www.youtube.com/watch?v=${videoId}"`,
      '--get-url',
      '-f "bestaudio[ext=m4a]/bestaudio/best"',
      '--no-warnings',
      '--extractor-args "youtube:player-client=web,mweb,default"',
    ].join(' ');

    exec(cmd, { timeout: 25000 }, (err, stdout, stderr) => {
      PENDING_FETCHES.delete(videoId);

      if (err || !stdout.trim()) {
        return reject(new Error(stderr || err?.message || 'No URL from yt-dlp'));
      }

      const url = stdout.trim().split('\n')[0];
      STREAM_CACHE.set(videoId, { url, expiresAt: Date.now() + CACHE_TTL_MS });
      console.log(`[CACHE] stored → ${videoId}`);
      resolve(url);
    });
  });

  PENDING_FETCHES.set(videoId, promise);
  return promise;
}

// ─── Utilitaire : meilleure miniature ───────────────────────────────────────
function bestThumb(item) {
  if (Array.isArray(item.thumbnails) && item.thumbnails.length) {
    const sorted = item.thumbnails
      .filter(t => t?.url)
      .sort((a, b) => (b.width ?? 0) - (a.width ?? 0));
    if (sorted.length) return sorted[0].url;
  }
  if (item.thumbnail) return item.thumbnail;
  if (item.id)        return `https://i.ytimg.com/vi/${item.id}/hqdefault.jpg`;
  return '';
}

app.listen(PORT, () => {
  console.log(`✅ Nono Music backend → http://localhost:${PORT}`);
  console.log(`   Cache TTL : 4h | URLs de stream mises en cache après 1ère lecture`);
});