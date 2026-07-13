-- ═══════════════════════════════════════════════════
-- カラオケオフ会 参加管理アプリ — Supabase セットアップSQL
-- （新規プロジェクトでのフレッシュインストール用。
--   既存プロジェクトを複数イベント対応にする場合は
--   本ファイル末尾の「既存DBへのマイグレーション」を参照）
-- ═══════════════════════════════════════════════════

-- ── テーブル: 参加者 ──────────────────────────────
-- event_id: どの回のデータかを表す（第一回=1, 第二回=2, …）
create table if not exists participants (
  id          uuid primary key default gen_random_uuid(),
  event_id    integer not null default 1,
  name        text not null,
  status      text not null
              check (status in ('going','maybe','tbd','absent')),
  comment     text not null default '',
  threads_id  text not null default '',
  residence   text not null default '',
  created_at  timestamptz not null default now()
);
create index if not exists idx_participants_event_id on participants(event_id);

-- ── テーブル: 設定 ────────────────────────────────
-- event_id=0 は全イベント共通（admin_pwのみ使用）、それ以外は各回専用の設定
create table if not exists settings (
  event_id integer not null default 1,
  key      text not null,
  value    text not null default '',
  primary key (event_id, key)
);

-- ── テーブル: 時間帯ブロック ──────────────────────
create table if not exists time_blocks (
  id         uuid primary key default gen_random_uuid(),
  event_id   integer not null default 1,
  label      text not null,
  sort_order integer not null default 0
);
create index if not exists idx_time_blocks_event_id on time_blocks(event_id);

-- ── テーブル: 参加者↔時間帯ブロック（中間テーブル） ──
create table if not exists participant_time_blocks (
  participant_id uuid references participants(id) on delete cascade,
  time_block_id  uuid references time_blocks(id)  on delete cascade,
  primary key (participant_id, time_block_id)
);

-- ── 初期データ（第一回 / event_id=1、admin_pwのみ event_id=0） ──
insert into settings (event_id, key, value) values
  (1, 'event_title',      'カラオケオフ会'),
  (1, 'event_datetime',   ''),   -- 旧フィールド（後方互換のため残す）
  (1, 'event_date',       ''),   -- 日付 例: 2025-06-15
  (1, 'event_start_time', ''),   -- 開始時刻 例: 18:00
  (1, 'event_end_time',   ''),   -- 終了時刻 例: 21:00
  (1, 'event_place',      ''),
  (1, 'event_place_url',  ''),   -- 場所のURL（GoogleマップなどのリンクURL）
  (1, 'organizer_name',        ''),   -- 幹事名
  (1, 'organizer_threads_id',  ''),   -- 幹事のThreads ID（例: @anego_threads）
  (1, 'event_notes',      ''),
  (1, 'notice',           ''),
  (0, 'admin_pw',         '')    -- 全イベント共通。アプリのセットアップ画面から自動設定される（平文）
on conflict (event_id, key) do nothing;

-- ── RLS (Row Level Security) ──────────────────────
alter table participants            enable row level security;
alter table settings                enable row level security;
alter table time_blocks             enable row level security;
alter table participant_time_blocks enable row level security;

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

-- time_blocks: 全員が読み書き可
create policy "read_time_blocks"
  on time_blocks for select using (true);
create policy "insert_time_blocks"
  on time_blocks for insert with check (true);
create policy "update_time_blocks"
  on time_blocks for update using (true);
create policy "delete_time_blocks"
  on time_blocks for delete using (true);

-- participant_time_blocks: 全員が読み書き可
create policy "read_ptb"
  on participant_time_blocks for select using (true);
create policy "insert_ptb"
  on participant_time_blocks for insert with check (true);
create policy "delete_ptb"
  on participant_time_blocks for delete using (true);

-- ── Realtime ──────────────────────────────────────
-- Supabase Dashboard > Database > Replication で
-- 下記テーブルにチェックが入っていることを確認すること。
alter publication supabase_realtime
  add table participants, settings, time_blocks, participant_time_blocks;

-- ════════════════════════════════════════════════════
-- 既存DBへのマイグレーション（event_id列が無い旧スキーマから移行する場合）
-- event/1 と event/2 以降がテーブルを共有してしまっている状態を解消し、
-- イベントごとにデータを分離する。既存プロジェクトのSQL Editorで一度だけ実行。
-- ════════════════════════════════════════════════════

-- 1. participants に event_id を追加し、既存データは全て第一回(1)に割り当て
alter table participants add column if not exists event_id integer;
update participants set event_id = 1 where event_id is null;
alter table participants alter column event_id set not null;
create index if not exists idx_participants_event_id on participants(event_id);

-- 2. time_blocks に event_id を追加し、既存データは全て第一回(1)に割り当て
alter table time_blocks add column if not exists event_id integer;
update time_blocks set event_id = 1 where event_id is null;
alter table time_blocks alter column event_id set not null;
create index if not exists idx_time_blocks_event_id on time_blocks(event_id);

-- 3. settings を (event_id, key) の複合主キーに変更
--    admin_pw だけは event_id = 0 として「全イベント共通」の特別な値にする
--    （トップページ・各回ページで同じ管理者パスワードを使う既存の挙動を維持するため）
alter table settings add column if not exists event_id integer;
update settings set event_id = 0 where key = 'admin_pw';
update settings set event_id = 1 where event_id is null;
alter table settings alter column event_id set not null;
alter table settings drop constraint if exists settings_pkey;
alter table settings add primary key (event_id, key);

-- 4. 第二回(event_id=2)用の初期設定行を作成（まだ無ければ）
insert into settings (event_id, key, value) values
  (2, 'event_title',      'カラオケオフ会'),
  (2, 'event_datetime',   ''),
  (2, 'event_date',       ''),
  (2, 'event_start_time', ''),
  (2, 'event_end_time',   ''),
  (2, 'event_place',      ''),
  (2, 'event_place_url',  ''),
  (2, 'organizer_name',        ''),
  (2, 'organizer_threads_id',  ''),
  (2, 'event_notes',      ''),
  (2, 'notice',           '')
on conflict (event_id, key) do nothing;
