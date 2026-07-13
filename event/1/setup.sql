-- ═══════════════════════════════════════════════════
-- カラオケオフ会 参加管理アプリ — Supabase セットアップSQL
-- ═══════════════════════════════════════════════════

-- ── テーブル: 参加者 ──────────────────────────────
create table if not exists participants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  status      text not null
              check (status in ('going','maybe','tbd','absent')),
  comment     text not null default '',
  created_at  timestamptz not null default now()
);

-- ── テーブル: 設定 ────────────────────────────────
create table if not exists settings (
  key   text primary key,
  value text not null default ''
);

-- ── 初期データ ────────────────────────────────────
insert into settings (key, value) values
  ('event_title',      'カラオケオフ会'),
  ('event_datetime',   ''),   -- 旧フィールド（後方互換のため残す）
  ('event_date',       ''),   -- 日付 例: 2025-06-15
  ('event_start_time', ''),   -- 開始時刻 例: 18:00
  ('event_end_time',   ''),   -- 終了時刻 例: 21:00
  ('event_place',      ''),
  ('event_place_url',  ''),   -- 場所のURL（GoogleマップなどのリンクURL）
  ('event_notes',      ''),
  ('notice',           ''),
  ('admin_pw',         '')    -- アプリのセットアップ画面から自動設定される（平文）
on conflict (key) do nothing;

-- ── RLS (Row Level Security) ──────────────────────
alter table participants enable row level security;
alter table settings     enable row level security;

-- participants: 全員が読み書き可（参加登録のため）
create policy "read_participants"
  on participants for select using (true);
create policy "insert_participants"
  on participants for insert with check (true);
create policy "update_participants"
  on participants for update using (true);
create policy "delete_participants"
  on participants for delete using (true);

-- settings: 全員が読み書き可（内輪利用前提）
-- ※ このアプリはSupabase Authを使わずアプリ側パスワードで管理者認証するため、
--   anon roleからのSELECT / INSERT / UPDATE をすべて許可する。
-- ※ admin_pw は平文保存。anon keyを知る人＝信頼できる人という前提でのみ使用すること。
create policy "read_settings"
  on settings for select using (true);
create policy "insert_settings"
  on settings for insert with check (true);
create policy "update_settings"
  on settings for update using (true);

-- ── Realtime ──────────────────────────────────────
-- Supabase Dashboard > Database > Replication で
-- 下記テーブルにチェックが入っていることを確認すること。
alter publication supabase_realtime
  add table participants, settings;

-- ════════════════════════════════════════════════════
-- 既存DBへのマイグレーション（すでにテーブルがある場合）
-- ════════════════════════════════════════════════════
-- ▼ settings テーブルに INSERT ポリシーを追加（必須）
--   「保存失敗: new row violates row-level security policy」が出る場合はこれを実行
--
-- create policy "insert_settings"
--   on settings for insert with check (true);
--
-- ▼ 新しいキーを追加（event_date 等が存在しない場合）
--
-- insert into settings (key, value) values
--   ('event_date',       ''),
--   ('event_start_time', ''),
--   ('event_end_time',   ''),
--   ('event_place_url',  '')
-- on conflict (key) do nothing;
