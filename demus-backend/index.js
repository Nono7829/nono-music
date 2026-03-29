const express = require('express');
const { exec } = require('child_process');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.get('/search', (req, res) => {
  const query = req.query.q;
  
  exec(`yt-dlp --get-id "ytsearch1:${query}"`, (err, stdout, stderr) => {
    if (err) return res.status(500).send({ error: err.message });
    res.send({ id: stdout.trim() });
  });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
