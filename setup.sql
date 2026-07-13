-- ═══════════════════════════════════════════════════
-- トップページ（index.html）用セットアップSQL
-- イベント一覧の追加・編集を管理者パネルから行うために必要
-- （各回の参加管理アプリ自体のSQLは event/<N>/setup.sql を参照）
-- ═══════════════════════════════════════════════════

-- テーブル: イベント一覧
create table if not exists events (
  id          uuid primary key default gen_random_uuid(),
  event_no    integer not null,
  title       text not null,
  event_date  date,
  url         text not null,
  created_at  timestamptz not null default now(),
  unique (event_no)
);

-- RLS（内輪利用前提。admin_pwはアプリ側で settings テーブルを参照して認証する）
alter table events enable row level security;

create policy "read_events"   on events for select using (true);
create policy "insert_events" on events for insert with check (true);
create policy "update_events" on events for update using (true);
create policy "delete_events" on events for delete using (true);

-- Realtime
alter publication supabase_realtime add table events;

-- 初期データ（第一回）
insert into events (event_no, title, event_date, url) values
  (1, '第一回 カラオケオフ会', '2026-07-13', 'event/1/index.html')
on conflict (event_no) do nothing;
