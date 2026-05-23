-- ============================================================
-- WealthSketcher Community Watchlist — Supabase Setup
-- Run this ONCE in Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Create the votes table
CREATE TABLE IF NOT EXISTS watchlist_votes (
  id          BIGSERIAL PRIMARY KEY,
  ticker      TEXT NOT NULL UNIQUE,
  votes       INT  NOT NULL DEFAULT 0,
  pct         NUMERIC(6,2) DEFAULT 0,   -- today's % change (updated by pipeline)
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Index for fast leaderboard queries
CREATE INDEX IF NOT EXISTS idx_votes_desc ON watchlist_votes(votes DESC);

-- 3. Atomic increment function (safe for concurrent users)
CREATE OR REPLACE FUNCTION increment_vote(p_ticker TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO watchlist_votes (ticker, votes)
  VALUES (p_ticker, 1)
  ON CONFLICT (ticker)
  DO UPDATE SET votes = watchlist_votes.votes + 1,
                updated_at = NOW();
END;
$$;

-- 4. Daily reset function (call this at midnight ET from pipeline)
CREATE OR REPLACE FUNCTION reset_daily_votes()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM watchlist_votes;
END;
$$;

-- 5. Allow public read (leaderboard visible to all)
ALTER TABLE watchlist_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read" ON watchlist_votes
  FOR SELECT USING (true);

-- 6. Allow public insert/update ONLY via the increment function
--    (not direct table writes — prevents vote manipulation)
CREATE POLICY "Function insert only" ON watchlist_votes
  FOR INSERT WITH CHECK (false);   -- direct inserts blocked

-- 7. Grant function execution to anonymous users
GRANT EXECUTE ON FUNCTION increment_vote TO anon;
GRANT EXECUTE ON FUNCTION reset_daily_votes TO service_role;
GRANT SELECT ON watchlist_votes TO anon;

-- ============================================================
-- DONE. Your table is ready.
-- Next step: copy your Project URL and anon key from
-- Supabase Dashboard → Settings → API
-- Paste them into index.html at the top of the <script> block
-- ============================================================
