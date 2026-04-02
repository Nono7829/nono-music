const express      = require('express');
const cors         = require('cors');
const { exec }     = require('child_process');
const https        = require('https');
const http         = require('http');

const app  = express();
const PORT = process.env.PORT || 3000;

// Utiliser la commande système yt-dlp (installée via pip dans le Dockerfile)
const YT_DLP = 'yt-dlp';

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : '*',
}));
app.use(express.json());

// ── Stream URL cache ─────────────────────────────────────────────────────────
const STREAM_CACHE    = new Map();
const CACHE_TTL_MS    = 4 * 60 * 60 * 1000;
const PENDING_FETCHES = new Map();

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ ok: true, ts: Date.now() }));

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
      resHeaders['Content-Range'] = proxyRes.headers['content-range'];

    res.writeHead(status, resHeaders);
    proxyRes.pipe(res);
    req.on('close', () => { try { proxyReq.destroy(); } catch (_) {} });
  });

  proxyReq.on('error', (err) => {
    console.error('[PROXY] pipe error:', err.message);
    if (!res.headersSent) res.status(502).json({ error: 'Proxy error', details: err.message });
  });
});

// ── GET /stream/:videoId ──────────────────────────────────────────────────────
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

// ── Stream URL resolution with cache ─────────────────────────────────────────
function getStreamUrl(videoId) {
  const cached = STREAM_CACHE.get(videoId);
  if (cached && Date.now() < cached.expiresAt) {
    console.log(`[CACHE] hit → ${videoId}`);
    return Promise.resolve(cached.url);
  }

  if (PENDING_FETCHES.has(videoId)) {
    console.log(`[CACHE] coalescing request → ${videoId}`);
    return PENDING_FETCHES.get(videoId);
  }

  console.log(`[CACHE] miss → fetching ${videoId}`);
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

// ── Best thumbnail ────────────────────────────────────────────────────────────
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

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Nono Music backend → http://0.0.0.0:${PORT}`);
  console.log(`   yt-dlp: ${YT_DLP}`);
  console.log(`   Cache TTL: 4h`);
});