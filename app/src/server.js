const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const pool = new Pool({
  user: process.env.POSTGRES_USER,
  host: process.env.POSTGRES_HOST,
  database: process.env.POSTGRES_DB,
  password: process.env.POSTGRES_PASSWORD,
  port: 5432,
});

app.post('/event', async (req, res) => {
  try {
    const  data  = req.body;
    await pool.query('INSERT INTO events (data, created_at) VALUES ($1, NOW())', [data]);
    res.status(201).json({ status: 'ok', message: 'Event saved' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ status: 'error', message: 'DB error' });
  }
});

app.get('/health', (req, res) => res.send('OK'));

const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));