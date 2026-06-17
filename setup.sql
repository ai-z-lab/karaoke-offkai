-- ═══════════════════════════════════════════════════
-- カラオケオフ会 参加管理アプリ — Supabase セットアップSQL
-- ═══════════════════════════════════════════════════

-- ── テーブル: 参加者 ──────────────────────────────
create table if not exists participants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  status      text not null
              check (status in ('going','maybe','tbd')),
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
  ('event_title',    'カラオケオフ会'),
  ('event_datetime', ''),
  ('event_place',    ''),
  ('event_notes',    ''),
  ('notice',         ''),
  ('admin_pw',       '')   -- アプリのセットアップ画面から自動設定される（平文）
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

-- settings: 全員が読める / 更新もMVPでは許可
-- ※ admin_pw は平文保存（シンプル化のため）。
--    anon keyを知っていれば理論上読み取れるため、
--    グルチャ内輪利用などURLを知る人＝信頼できる人、
--    という前提でのみ使用すること。
-- ※ 本番移行時は update を service_role のみに変更推奨
create policy "read_settings"
  on settings for select using (true);
create policy "update_settings"
  on settings for update using (true);

-- ── Realtime ──────────────────────────────────────
-- Supabase Dashboard > Database > Replication で
-- 下記2テーブルにチェックが入っていることを確認すること。
-- SQL での有効化コマンド（すでに有効なら不要）:
alter publication supabase_realtime
  add table participants, settings;
