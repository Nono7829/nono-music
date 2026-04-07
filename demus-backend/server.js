const express      = require('express');
const cors         = require('cors');
const { exec }     = require('child_process');
const https        = require('https');
const http         = require('http');

const app  = express();
const PORT = process.env.PORT || 3000;
const YT_DLP = 'yt-dlp';

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : '*',
}));
app.use(express.json());

// ── Stream URL cache ──────────────────────────────────────────────────────────
const STREAM_CACHE    = new Map();
const CACHE_TTL_MS    = 3 * 60 * 60 * 1000; // 3h — YouTube URLs valid ~6h
const PENDING_FETCHES = new Map();

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({
  ok: true,
  ts: Date.now(),
  cacheSize: STREAM_CACHE.size,
  version: '2.0.0',
}));

// ── GET /search?q=... ─────────────────────────────────────────────────────────
app.get('/search', (req, res) => {
  const query = (req.query.q || '').trim();
  if (!query) return res.status(400).json({ error: 'Missing parameter: q' });

  console.log(`[SEARCH] "${query}"`);
  const safeQuery = query.replace(/"/g, '\\"');
  const cmd = [
    `"${YT_DLP}"`,
    `"ytsearch40:${safeQuery}"`,
    '--dump-json',
    '--flat-playlist',
    '--no-warnings',
    '--ignore-errors',
    '--socket-timeout 8',
  ].join(' ');

  exec(cmd, { maxBuffer: 1024 * 1024 * 20, timeout: 28000 }, (err, stdout, stderr) => {
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
        if (!id || id.length !== 11) continue;
        const dur = item.duration ?? 0;
        if (dur > 1800) continue;
        results.push({
          id,
          title:     item.title    ?? 'Unknown title',
          artist:    item.uploader ?? item.channel ?? 'Unknown artist',
          duration:  dur,
          thumbnail: bestThumb(item),
        });
      } catch (_) {}
    }

    console.log(`[SEARCH] → ${results.length} results`);
    return res.json({ results });
  });
});

// ── GET /proxy/:videoId ───────────────────────────────────────────────────────
app.get('/proxy/:videoId', async (req, res) => {
  const { videoId } = req.params;
  if (!/^[a-zA-Z0-9_-]{11}$/.test(videoId)) {
    return res.status(400).json({ error: 'Invalid videoId format' });
  }
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
  const proxyReq  = transport.get(streamUrl, { headers: reqHeaders }, (proxyRes) => {
    const status = proxyRes.statusCode ?? 200;

    if (status === 403 || status === 410) {
      STREAM_CACHE.delete(videoId);
      console.warn(`[PROXY] ${status} — cache invalidated for ${videoId}`);
      if (!res.headersSent) {
        res.status(status).json({ error: `YouTube returned ${status}` });
      }
      return;
    }

    const resHeaders = {
      'Content-Type':  proxyRes.headers['content-type'] || 'audio/mp4',
      'Accept-Ranges': 'bytes',
    };
    if (proxyRes.headers['content-length'])
      resHeaders['Content-Length'] = proxyRes.headers['content-length'];
    if (proxyRes.headers['content-range'])
      resHeaders['Content-Range']  = proxyRes.headers['content-range'];

    res.writeHead(status, resHeaders);
    proxyRes.pipe(res);
    req.on('close', () => { try { proxyReq.destroy(); } catch (_) {} });
  });

  // Timeout connexion initiale CDN YouTube (≠ durée totale du stream)
  proxyReq.setTimeout(15000, () => {
    proxyReq.destroy();
    if (!res.headersSent) res.status(504).json({ error: 'CDN connection timeout' });
  });

  proxyReq.on('error', (err) => {
    console.error('[PROXY] pipe error:', err.message);
    if (!res.headersSent) res.status(502).json({ error: 'Proxy error', details: err.message });
  });
});

// ── GET /stream/:videoId ──────────────────────────────────────────────────────
app.get('/stream/:videoId', async (req, res) => {
  const { videoId } = req.params;
  if (!/^[a-zA-Z0-9_-]{11}$/.test(videoId)) {
    return res.status(400).json({ error: 'Invalid videoId format' });
  }
  console.log(`[STREAM] ${videoId}`);
  try {
    const url = await getStreamUrl(videoId);
    return res.json({ url, cached: STREAM_CACHE.has(videoId) });
  } catch (err) {
    return res.status(500).json({ error: 'Cannot get stream', details: err.message });
  }
});

// ── Stream URL resolution — cache + coalescing + retry ────────────────────────
function getStreamUrl(videoId) {
  const cached = STREAM_CACHE.get(videoId);
  if (cached && Date.now() < cached.expiresAt) {
    console.log(`[CACHE] hit → ${videoId}`);
    return Promise.resolve(cached.url);
  }

  if (PENDING_FETCHES.has(videoId)) {
    console.log(`[CACHE] coalescing → ${videoId}`);
    return PENDING_FETCHES.get(videoId);
  }

  console.log(`[CACHE] miss → fetching ${videoId}`);
  const promise = _fetchWithRetry(videoId, 2);
  PENDING_FETCHES.set(videoId, promise);
  promise.finally(() => PENDING_FETCHES.delete(videoId));
  return promise;
}

function _fetchWithRetry(videoId, retriesLeft) {
  return _fetchOnce(videoId).catch((err) => {
    if (retriesLeft > 0) {
      console.warn(`[CACHE] retry (${retriesLeft} left) → ${videoId} — ${err.message}`);
      return new Promise((res) => setTimeout(res, 1500))
        .then(() => _fetchWithRetry(videoId, retriesLeft - 1));
    }
    throw err;
  });
}

function _fetchOnce(videoId) {
  return new Promise((resolve, reject) => {
    // ios + tv_embedded = player clients les plus fiables contre la détection bot
    const cmd = [
      `"${YT_DLP}"`,
      `"https://www.youtube.com/watch?v=${videoId}"`,
      '--get-url',
      '-f "bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio/best"',
      '--no-warnings',
      '--no-playlist',
      '--socket-timeout 8',
      '--extractor-args "youtube:player_client=ios,tv_embedded,web"',
    ].join(' ');

    exec(cmd, { timeout: 22000 }, (err, stdout, stderr) => {
      if (err || !stdout.trim()) {
        const msg = stderr?.trim() || err?.message || 'No URL from yt-dlp';
        return reject(new Error(msg));
      }
      const url = stdout.trim().split('\n')[0];
      if (!url.startsWith('http')) {
        return reject(new Error(`Invalid URL returned: ${url.substring(0, 80)}`));
      }
      STREAM_CACHE.set(videoId, { url, expiresAt: Date.now() + CACHE_TTL_MS });
      console.log(`[CACHE] stored → ${videoId}`);
      resolve(url);
    });
  });
}

// ── GET /import-playlist?url=... ─────────────────────────────────────────────
app.get('/import-playlist', (req, res) => {
  const url = (req.query.url || '').trim();
  if (!url) return res.status(400).json({ error: 'Missing parameter: url' });

  console.log(`[IMPORT] ${url}`);
  const safeUrl = url.replace(/"/g, '\\"');
  const cmd = [
    `"${YT_DLP}"`,
    `"${safeUrl}"`,
    '--dump-json',
    '--flat-playlist',
    '--no-warnings',
    '--ignore-errors',
    '--socket-timeout 8',
  ].join(' ');

  exec(cmd, { maxBuffer: 1024 * 1024 * 50, timeout: 60000 }, (err, stdout, stderr) => {
    if (stderr) console.warn('[IMPORT] stderr:', stderr.substring(0, 200));
    if (err && !stdout) {
      return res.status(500).json({ error: 'yt-dlp import failed', details: err.message });
    }

    const tracks = [];
    for (const line of stdout.split('\n').filter(Boolean)) {
      try {
        const item = JSON.parse(line);
        const id = item.id ?? null;
        if (!id || id.length !== 11) continue;
        const dur = item.duration ?? 0;
        if (dur > 1800) continue;
        tracks.push({
          id,
          title:     item.title    ?? 'Unknown title',
          artist:    item.uploader ?? item.channel ?? 'Unknown artist',
          duration:  dur,
          thumbnail: bestThumb(item),
        });
      } catch (_) {}
    }

    console.log(`[IMPORT] → ${tracks.length} tracks`);
    return res.json({ tracks });
  });
});

// ── Spotify ───────────────────────────────────────────────────────────────────
let _spotifyToken       = null;
let _spotifyTokenExpiry = 0;

async function getSpotifyToken() {
  if (_spotifyToken && Date.now() < _spotifyTokenExpiry) return _spotifyToken;
  const id     = process.env.SPOTIFY_CLIENT_ID;
  const secret = process.env.SPOTIFY_CLIENT_SECRET;
  if (!id || !secret) throw new Error('SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET manquants');
  const creds = Buffer.from(`${id}:${secret}`).toString('base64');
  const res   = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      'Content-Type':  'application/x-www-form-urlencoded',
      'Authorization': `Basic ${creds}`,
    },
    body: 'grant_type=client_credentials',
  });
  const data          = await res.json();
  _spotifyToken       = data.access_token;
  _spotifyTokenExpiry = Date.now() + (data.expires_in - 60) * 1000;
  return _spotifyToken;
}

async function resolveYouTubeId(title, artist) {
  return new Promise((resolve) => {
    const q   = `${artist} - ${title} official audio`;
    const safeQ = q.replace(/"/g, '\\"');
    const cmd = `"${YT_DLP}" "ytsearch1:${safeQ}" --get-id --no-warnings --flat-playlist --socket-timeout 6`;
    exec(cmd, { timeout: 12000 }, (err, stdout) => {
      if (err || !stdout.trim()) return resolve(null);
      const id = stdout.trim().split('\n')[0].trim();
      resolve(id.length === 11 ? id : null);
    });
  });
}

app.get('/spotify-search', async (req, res) => {
  const q = (req.query.q || '').trim();
  if (!q) return res.status(400).json({ error: 'Paramètre q manquant' });

  try {
    const token    = await getSpotifyToken();
    const spotRes  = await fetch(
      `https://api.spotify.com/v1/search?q=${encodeURIComponent(q)}&type=track&limit=15&market=FR`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    const spotData = await spotRes.json();
    const tracks   = spotData.tracks?.items || [];

    console.log(`[SPOTIFY] "${q}" → ${tracks.length} tracks, resolving YouTube…`);

    const BATCH = 5;
    const results = [];
    for (let i = 0; i < tracks.length; i += BATCH) {
      const batch   = tracks.slice(i, i + BATCH);
      const resolved = await Promise.allSettled(
        batch.map(async (t) => {
          const ytId = await resolveYouTubeId(t.name, t.artists[0]?.name || '');
          if (!ytId) return null;
          return {
            id:        ytId,
            title:     t.name,
            artist:    t.artists.map((a) => a.name).join(', '),
            thumbnail: t.album.images[0]?.url || `https://i.ytimg.com/vi/${ytId}/hqdefault.jpg`,
            duration:  Math.floor(t.duration_ms / 1000),
          };
        })
      );
      for (const r of resolved) {
        if (r.status === 'fulfilled' && r.value) results.push(r.value);
      }
    }

    console.log(`[SPOTIFY] → ${results.length} results resolved`);
    res.json({ results });
  } catch (e) {
    console.error('[SPOTIFY] Error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── Best thumbnail ────────────────────────────────────────────────────────────
function bestThumb(item) {
  if (Array.isArray(item.thumbnails) && item.thumbnails.length) {
    const sorted = item.thumbnails
      .filter((t) => t?.url)
      .sort((a, b) => (b.width ?? 0) - (a.width ?? 0));
    if (sorted.length) return sorted[0].url;
  }
  if (item.thumbnail) return item.thumbnail;
  if (item.id)        return `https://i.ytimg.com/vi/${item.id}/hqdefault.jpg`;
  return '';
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Nono Music backend → http://0.0.0.0:${PORT}`);
  console.log(`   yt-dlp : ${YT_DLP}`);
  console.log(`   Cache TTL : 3h`);
  console.log(`   Player clients : ios, tv_embedded, web`);
});