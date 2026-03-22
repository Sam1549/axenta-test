const express = require('express');
const { Pool } = require('pg');
const { createClient } = require('@clickhouse/client');
const { format } = require('date-fns');

const app = express();
app.use(express.json());

const pool = new Pool({
  user: process.env.POSTGRES_USER,
  host: process.env.POSTGRES_HOST,
  database: process.env.POSTGRES_DB,
  password: process.env.POSTGRES_PASSWORD,
  port: 5432,
});

const clickhouse = createClient({
  host: process.env.CLICKHOUSE_HOST,
  username: process.env.CLICKHOUSE_USER,
  password: process.env.CLICKHOUSE_PASSWORD,
  database: process.env.CLICKHOUSE_DB,
});

app.post('/event', async (req, res) => {
  try {
    const  data  = req.body;
    const timestamp = format(new Date(), 'yyyy-MM-dd HH:mm:ss');
    await pool.query('INSERT INTO events (data, created_at) VALUES ($1, NOW())', [data]);
     await clickhouse.insert({
      table: 'events',
      values: [{ 
        id: Date.now(), 
        data: JSON.stringify(data), 
        created_at: timestamp 
      }],
      format: 'JSONEachRow',
    });
    res.status(201).json({ status: 'ok', message: 'Event saved' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ status: 'error', message: 'DB error' });
  }
});

app.get('/health', (req, res) => res.send('OK'));

const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));