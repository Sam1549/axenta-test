CREATE TABLE IF NOT EXISTS events (
  id UInt64,
  data String,
  created_at DateTime
) ENGINE = MergeTree()
ORDER BY created_at;