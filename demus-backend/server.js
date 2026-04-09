const express      = require('express');
const cors         = require('cors');
const { exec }     = require('child_process');
const https        = require('https');
const http         = require('http');

const app  = express();
const PORT = process.env.PORT || 3000;
const YT_DLP = 'yt-dlp';

const YTDLP_SEARCH_TIMEOUT_MS  = parseInt(process.env.YTDLP_SEARCH_TIMEOUT_MS  || '28000', 10);
const YTDLP_STREAM_TIMEOUT_MS  = parseInt(process.env.YTDLP_STREAM_TIMEOUT_MS  || '22000', 10);
const CDN_CONNECT_TIMEOUT_MS   = parseInt(process.env.CDN_CONNECT_TIMEOUT_MS   || '15000', 10);
const UNIFIED_SEARCH_TIMEOUT_MS = parseInt(process.env.UNIFIED_SEARCH_TIMEOUT_MS || '30000', 10);

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*',
}));
app.use(express.json());

const STREAM_CACHE    = new Map();
const CACHE_TTL_MS    = 3 * 60 * 60 * 1000; 
const PENDING_FETCHES = new Map();

// ── INFRA RENDER : Éviter la coupure auto ──────────────────────────────────────
const server = http.createServer(app);
server.keepAliveTimeout = 61000; 
server.headersTimeout = 65000;

app.get('/health', (_, res) => res.json({ ok: true, version: '3.0.0' }));

// ── SEARCH UNIFIED (P1) ───────────────────────────────────────────────────────
app.get('/unified-search', async (req, res) => {
  const query = (req.query.q || '').trim();
  if (!query) return res.status(400).json({ error: 'Missing parameter: q' });

  const deadline = Date.now() + UNIFIED_SEARCH_TIMEOUT_MS;
  const [ytResult, spotResult] = await Promise.allSettled([
    fetchYouTubeSearch(query, Math.min(30000, YTDLP_SEARCH_TIMEOUT_MS)),
    fetchSpotifySearch(query),
  ]);

  const ytTracks    = ytResult.status === 'fulfilled' ? ytResult.value : [];
  const spotTracks  = spotResult.status === 'fulfilled' ? spotResult.value : [];

  const seen = new Set();
  const results = [];

  function fingerprint(title, artist) {
    return `${normalize(title)}|${normalize(artist)}`;
  }
  function normalize(s) {
    return (s || '').toLowerCase().replace(/\(.*?\)/g, '').replace(/\[.*?\]/g, '').replace(/[^\w\s]/g, '').replace(/\s+/g, ' ').trim();
  }

  for (const t of spotTracks) {
    if (Date.now() > deadline) break;
    const fp = fingerprint(t.title, t.artist);
    if (seen.has(fp)) continue;
    seen.add(fp);
    results.push({ ...t, source: 'spotify' });
  }

  for (const t of ytTracks) {
    const fp = fingerprint(t.title, t.artist);
    if (seen.has(fp)) continue;
    seen.add(fp);
    results.push({ ...t, source: 'youtube' });
  }

  return res.json({ results });
});

// Helpers YouTube/Spotify (Garder tes fonctions existantes : fetchYouTubeSearch, fetchSpotifySearch, getSpotifyToken, resolveYouTubeId)
// ... [Insère ici tes fonctions fetchYouTubeSearch, fetchSpotifySearch, getSpotifyToken, resolveYouTubeId] ...

// ── PROXY AUDIO ────────────────────────────────────────────────────────────────
app.get('/proxy/:videoId', async (req, res) => {
  const { videoId } = req.params;
  if (!/^[a-zA-Z0-9_-]{11}$/.test(videoId)) return res.status(400).json({ error: 'Invalid ID' });

  try {
    const streamUrl = await getStreamUrl(videoId);
    const rangeHeader = req.headers['range'];
    const transport = streamUrl.startsWith('https') ? https : http;
    
    const proxyReq = transport.get(streamUrl, { 
      headers: { 
        'User-Agent': 'Mozilla/5.0', 
        ...(rangeHeader ? { Range: rangeHeader } : {}) 
      } 
    }, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, {
        'Content-Type': proxyRes.headers['content-type'] || 'audio/mp4',
        'Accept-Ranges': 'bytes',
      });
      proxyRes.pipe(res);
    });

    proxyReq.setTimeout(CDN_CONNECT_TIMEOUT_MS, () => {
      proxyReq.destroy();
      if (!res.headersSent) res.status(504).send('Timeout');
    });
  } catch (e) {
    if (!res.headersSent) res.status(500).send('Error');
  }
});

// ... [Garder tes fonctions getStreamUrl, _fetchWithRetry, _fetchOnce] ...

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Backend Production Grade on port ${PORT}`);
});
