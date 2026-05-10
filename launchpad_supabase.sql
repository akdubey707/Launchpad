-- ══════════════════════════════════════════════════════════════
--  Launchpad · Supabase Table Setup
--  Run this in: Supabase Dashboard → SQL Editor → New Query
-- ══════════════════════════════════════════════════════════════

-- 1. Create the apps table
CREATE TABLE IF NOT EXISTS public.apps (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT        NOT NULL,
  url         TEXT        NOT NULL,
  icon        TEXT        DEFAULT '',
  category    TEXT        DEFAULT '',
  "order"     INTEGER     DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Index for fast order-based sorting
CREATE INDEX IF NOT EXISTS apps_order_idx ON public.apps ("order" ASC);

-- 3. Auto-update the updated_at timestamp on every row change
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON public.apps;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.apps
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 4. Disable Row Level Security so the anon key can read/write freely
--    (use RLS policies instead if you want auth-gated access)
ALTER TABLE public.apps DISABLE ROW LEVEL SECURITY;

-- ── Optional: enable RLS with a public policy instead ──────────
-- ALTER TABLE public.apps ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow public access" ON public.apps
--   FOR ALL USING (true) WITH CHECK (true);
-- ───────────────────────────────────────────────────────────────

-- 5. Grant full access to the anon and authenticated roles
GRANT ALL ON public.apps TO anon;
GRANT ALL ON public.apps TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.apps_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.apps_id_seq TO authenticated;

-- ══════════════════════════════════════════════════════════════
--  Verify setup — should return the table definition
-- ══════════════════════════════════════════════════════════════
SELECT column_name, data_type, is_nullable, column_default
FROM   information_schema.columns
WHERE  table_schema = 'public'
  AND  table_name   = 'apps'
ORDER BY ordinal_position;
