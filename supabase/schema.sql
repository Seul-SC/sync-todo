-- 同步待办 · 空库一次跑完
-- 表 / 索引 / RLS / 后写覆盖先写（禁止服务器改写 updated_at）
-- 含待办 content/series_id、笔记、文件夹、关联、用户时区设置

create extension if not exists "pgcrypto";

grant usage on schema public to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 通用 LWW：拒绝过期写入；绝不把 updated_at 改成服务器 now()
-- ---------------------------------------------------------------------------
create or replace function public.lww_updated_at_guard()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at is null then
    raise exception 'updated_at is required';
  end if;

  if tg_op = 'UPDATE' then
    if new.updated_at <= old.updated_at then
      return null;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 待办表
-- ---------------------------------------------------------------------------
create table if not exists public.todos (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  content text not null default '',
  remind_at timestamptz,
  recurrence text not null default 'none'
    check (recurrence in ('none', 'daily', 'weekly')),
  weekdays int[] default null,
  completed boolean not null default false,
  series_id uuid references public.todos (id) on delete set null,
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null
);

alter table public.todos add column if not exists content text not null default '';
alter table public.todos add column if not exists series_id uuid references public.todos (id) on delete set null;

create index if not exists todos_user_id_idx on public.todos (user_id);
create index if not exists todos_user_updated_idx on public.todos (user_id, updated_at);
create index if not exists todos_user_deleted_idx on public.todos (user_id, deleted_at);
create index if not exists todos_series_id_idx on public.todos (series_id);

alter table public.todos enable row level security;

drop policy if exists "todos_select_own" on public.todos;
create policy "todos_select_own"
  on public.todos for select
  using (auth.uid() = user_id);

drop policy if exists "todos_insert_own" on public.todos;
create policy "todos_insert_own"
  on public.todos for insert
  with check (auth.uid() = user_id);

drop policy if exists "todos_update_own" on public.todos;
create policy "todos_update_own"
  on public.todos for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "todos_delete_own" on public.todos;
create policy "todos_delete_own"
  on public.todos for delete
  using (auth.uid() = user_id);

drop trigger if exists todos_lww_guard_trg on public.todos;
create trigger todos_lww_guard_trg
  before insert or update on public.todos
  for each row
  execute function public.lww_updated_at_guard();

drop function if exists public.upsert_todo(
  uuid, text, timestamptz, text, int[], boolean, timestamptz, timestamptz, timestamptz
);

create or replace function public.upsert_todo(
  p_id uuid,
  p_title text,
  p_content text,
  p_remind_at timestamptz,
  p_recurrence text,
  p_weekdays int[],
  p_completed boolean,
  p_series_id uuid,
  p_deleted_at timestamptz,
  p_created_at timestamptz,
  p_updated_at timestamptz
)
returns public.todos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.todos;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.todos as t (
    id, user_id, title, content, remind_at, recurrence, weekdays,
    completed, series_id, deleted_at, created_at, updated_at
  ) values (
    p_id, v_uid, p_title, coalesce(p_content, ''), p_remind_at,
    coalesce(p_recurrence, 'none'), p_weekdays,
    coalesce(p_completed, false), p_series_id, p_deleted_at,
    coalesce(p_created_at, p_updated_at), p_updated_at
  )
  on conflict (id) do update set
    title = excluded.title,
    content = excluded.content,
    remind_at = excluded.remind_at,
    recurrence = excluded.recurrence,
    weekdays = excluded.weekdays,
    completed = excluded.completed,
    series_id = excluded.series_id,
    deleted_at = excluded.deleted_at,
    updated_at = excluded.updated_at
  where t.user_id = v_uid
    and t.updated_at < excluded.updated_at
  returning * into v_row;

  if v_row.id is null then
    select * into v_row from public.todos where id = p_id and user_id = v_uid;
  end if;

  return v_row;
end;
$$;

revoke all on function public.upsert_todo(
  uuid, text, text, timestamptz, text, int[], boolean, uuid, timestamptz, timestamptz, timestamptz
) from public;
grant execute on function public.upsert_todo(
  uuid, text, text, timestamptz, text, int[], boolean, uuid, timestamptz, timestamptz, timestamptz
) to authenticated;

grant select, insert, update, delete on table public.todos to authenticated;

-- ---------------------------------------------------------------------------
-- 文件夹
-- ---------------------------------------------------------------------------
create table if not exists public.folders (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  parent_id uuid references public.folders (id) on delete set null,
  name text not null,
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null
);

create index if not exists folders_user_id_idx on public.folders (user_id);
create index if not exists folders_user_updated_idx on public.folders (user_id, updated_at);
create index if not exists folders_parent_id_idx on public.folders (parent_id);

alter table public.folders enable row level security;

drop policy if exists "folders_select_own" on public.folders;
create policy "folders_select_own"
  on public.folders for select
  using (auth.uid() = user_id);

drop policy if exists "folders_insert_own" on public.folders;
create policy "folders_insert_own"
  on public.folders for insert
  with check (auth.uid() = user_id);

drop policy if exists "folders_update_own" on public.folders;
create policy "folders_update_own"
  on public.folders for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "folders_delete_own" on public.folders;
create policy "folders_delete_own"
  on public.folders for delete
  using (auth.uid() = user_id);

drop trigger if exists folders_lww_guard_trg on public.folders;
create trigger folders_lww_guard_trg
  before insert or update on public.folders
  for each row
  execute function public.lww_updated_at_guard();

create or replace function public.upsert_folder(
  p_id uuid,
  p_parent_id uuid,
  p_name text,
  p_deleted_at timestamptz,
  p_created_at timestamptz,
  p_updated_at timestamptz
)
returns public.folders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.folders;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.folders as t (
    id, user_id, parent_id, name, deleted_at, created_at, updated_at
  ) values (
    p_id, v_uid, p_parent_id, p_name, p_deleted_at,
    coalesce(p_created_at, p_updated_at), p_updated_at
  )
  on conflict (id) do update set
    parent_id = excluded.parent_id,
    name = excluded.name,
    deleted_at = excluded.deleted_at,
    updated_at = excluded.updated_at
  where t.user_id = v_uid
    and t.updated_at < excluded.updated_at
  returning * into v_row;

  if v_row.id is null then
    select * into v_row from public.folders where id = p_id and user_id = v_uid;
  end if;

  return v_row;
end;
$$;

revoke all on function public.upsert_folder(
  uuid, uuid, text, timestamptz, timestamptz, timestamptz
) from public;
grant execute on function public.upsert_folder(
  uuid, uuid, text, timestamptz, timestamptz, timestamptz
) to authenticated;

grant select, insert, update, delete on table public.folders to authenticated;

-- ---------------------------------------------------------------------------
-- 笔记
-- ---------------------------------------------------------------------------
create table if not exists public.notes (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  folder_id uuid references public.folders (id) on delete set null,
  title text not null default '',
  content text not null default '',
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null
);

create index if not exists notes_user_id_idx on public.notes (user_id);
create index if not exists notes_user_updated_idx on public.notes (user_id, updated_at);
create index if not exists notes_folder_id_idx on public.notes (folder_id);

alter table public.notes enable row level security;

drop policy if exists "notes_select_own" on public.notes;
create policy "notes_select_own"
  on public.notes for select
  using (auth.uid() = user_id);

drop policy if exists "notes_insert_own" on public.notes;
create policy "notes_insert_own"
  on public.notes for insert
  with check (auth.uid() = user_id);

drop policy if exists "notes_update_own" on public.notes;
create policy "notes_update_own"
  on public.notes for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "notes_delete_own" on public.notes;
create policy "notes_delete_own"
  on public.notes for delete
  using (auth.uid() = user_id);

drop trigger if exists notes_lww_guard_trg on public.notes;
create trigger notes_lww_guard_trg
  before insert or update on public.notes
  for each row
  execute function public.lww_updated_at_guard();

create or replace function public.upsert_note(
  p_id uuid,
  p_folder_id uuid,
  p_title text,
  p_content text,
  p_deleted_at timestamptz,
  p_created_at timestamptz,
  p_updated_at timestamptz
)
returns public.notes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.notes;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.notes as t (
    id, user_id, folder_id, title, content, deleted_at, created_at, updated_at
  ) values (
    p_id, v_uid, p_folder_id, coalesce(p_title, ''), coalesce(p_content, ''),
    p_deleted_at, coalesce(p_created_at, p_updated_at), p_updated_at
  )
  on conflict (id) do update set
    folder_id = excluded.folder_id,
    title = excluded.title,
    content = excluded.content,
    deleted_at = excluded.deleted_at,
    updated_at = excluded.updated_at
  where t.user_id = v_uid
    and t.updated_at < excluded.updated_at
  returning * into v_row;

  if v_row.id is null then
    select * into v_row from public.notes where id = p_id and user_id = v_uid;
  end if;

  return v_row;
end;
$$;

revoke all on function public.upsert_note(
  uuid, uuid, text, text, timestamptz, timestamptz, timestamptz
) from public;
grant execute on function public.upsert_note(
  uuid, uuid, text, text, timestamptz, timestamptz, timestamptz
) to authenticated;

grant select, insert, update, delete on table public.notes to authenticated;

-- ---------------------------------------------------------------------------
-- 笔记 ↔ 待办 关联
-- ---------------------------------------------------------------------------
create table if not exists public.note_todo_links (
  note_id uuid not null references public.notes (id) on delete cascade,
  todo_id uuid not null references public.todos (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (note_id, todo_id)
);

create index if not exists note_todo_links_user_id_idx on public.note_todo_links (user_id);
create index if not exists note_todo_links_todo_id_idx on public.note_todo_links (todo_id);

alter table public.note_todo_links enable row level security;

drop policy if exists "note_todo_links_select_own" on public.note_todo_links;
create policy "note_todo_links_select_own"
  on public.note_todo_links for select
  using (auth.uid() = user_id);

drop policy if exists "note_todo_links_insert_own" on public.note_todo_links;
create policy "note_todo_links_insert_own"
  on public.note_todo_links for insert
  with check (auth.uid() = user_id);

drop policy if exists "note_todo_links_update_own" on public.note_todo_links;
create policy "note_todo_links_update_own"
  on public.note_todo_links for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "note_todo_links_delete_own" on public.note_todo_links;
create policy "note_todo_links_delete_own"
  on public.note_todo_links for delete
  using (auth.uid() = user_id);

grant select, insert, update, delete on table public.note_todo_links to authenticated;

-- ---------------------------------------------------------------------------
-- 用户设置（时区）
-- ---------------------------------------------------------------------------
create table if not exists public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  timezone text not null default 'system',
  updated_at timestamptz not null
);

alter table public.user_settings enable row level security;

drop policy if exists "user_settings_select_own" on public.user_settings;
create policy "user_settings_select_own"
  on public.user_settings for select
  using (auth.uid() = user_id);

drop policy if exists "user_settings_insert_own" on public.user_settings;
create policy "user_settings_insert_own"
  on public.user_settings for insert
  with check (auth.uid() = user_id);

drop policy if exists "user_settings_update_own" on public.user_settings;
create policy "user_settings_update_own"
  on public.user_settings for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_settings_delete_own" on public.user_settings;
create policy "user_settings_delete_own"
  on public.user_settings for delete
  using (auth.uid() = user_id);

drop trigger if exists user_settings_lww_guard_trg on public.user_settings;
create trigger user_settings_lww_guard_trg
  before insert or update on public.user_settings
  for each row
  execute function public.lww_updated_at_guard();

create or replace function public.upsert_user_settings(
  p_timezone text,
  p_updated_at timestamptz
)
returns public.user_settings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_settings;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.user_settings as t (user_id, timezone, updated_at)
  values (v_uid, coalesce(p_timezone, 'system'), p_updated_at)
  on conflict (user_id) do update set
    timezone = excluded.timezone,
    updated_at = excluded.updated_at
  where t.updated_at < excluded.updated_at
  returning * into v_row;

  if v_row.user_id is null then
    select * into v_row from public.user_settings where user_id = v_uid;
  end if;

  return v_row;
end;
$$;

revoke all on function public.upsert_user_settings(text, timestamptz) from public;
grant execute on function public.upsert_user_settings(text, timestamptz) to authenticated;

grant select, insert, update, delete on table public.user_settings to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime：让另一端尽快收到完成 / 稍后提醒
-- ---------------------------------------------------------------------------
do $$
declare
  r text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    return;
  end if;
  foreach r in array array['todos', 'folders', 'notes', 'note_todo_links', 'user_settings']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = r
    ) then
      execute format('alter publication supabase_realtime add table public.%I', r);
    end if;
  end loop;
end;
$$;

-- 可选：应用内更新公共桶（默认不要在生产上盲目执行；由运维按需打开）
-- insert into storage.buckets (id, name, public)
-- values ('app-updates', 'app-updates', true)
-- on conflict (id) do nothing;
