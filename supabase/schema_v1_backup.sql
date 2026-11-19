-- 同步待办 · 空项目一次跑完
-- 表 / 索引 / RLS / 后写覆盖先写（禁止服务器改写 updated_at）

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 待办表
-- ---------------------------------------------------------------------------
create table if not exists public.todos (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  remind_at timestamptz,
  recurrence text not null default 'none'
    check (recurrence in ('none', 'daily', 'weekly')),
  weekdays int[] default null,
  completed boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null
);

create index if not exists todos_user_id_idx on public.todos (user_id);
create index if not exists todos_user_updated_idx on public.todos (user_id, updated_at);
create index if not exists todos_user_deleted_idx on public.todos (user_id, deleted_at);

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

-- ---------------------------------------------------------------------------
-- 后写覆盖先写：拒绝过期写入；绝不把 updated_at 改成服务器 now()
-- ---------------------------------------------------------------------------
create or replace function public.todos_lww_guard()
returns trigger
language plpgsql
as $$
begin
  -- 客户端必须自带 updated_at；禁止空值
  if new.updated_at is null then
    raise exception 'updated_at is required';
  end if;

  if tg_op = 'UPDATE' then
    if new.updated_at <= old.updated_at then
      -- 丢弃过期写入，保留库中已有行
      return null;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists todos_lww_guard_trg on public.todos;
create trigger todos_lww_guard_trg
  before insert or update on public.todos
  for each row
  execute function public.todos_lww_guard();

-- 客户端可用的 upsert：仅当传入 updated_at 更新时才覆盖
create or replace function public.upsert_todo(
  p_id uuid,
  p_title text,
  p_remind_at timestamptz,
  p_recurrence text,
  p_weekdays int[],
  p_completed boolean,
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
    id, user_id, title, remind_at, recurrence, weekdays,
    completed, deleted_at, created_at, updated_at
  ) values (
    p_id, v_uid, p_title, p_remind_at, coalesce(p_recurrence, 'none'), p_weekdays,
    coalesce(p_completed, false), p_deleted_at, coalesce(p_created_at, p_updated_at), p_updated_at
  )
  on conflict (id) do update set
    title = excluded.title,
    remind_at = excluded.remind_at,
    recurrence = excluded.recurrence,
    weekdays = excluded.weekdays,
    completed = excluded.completed,
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
  uuid, text, timestamptz, text, int[], boolean, timestamptz, timestamptz, timestamptz
) from public;
grant execute on function public.upsert_todo(
  uuid, text, timestamptz, text, int[], boolean, timestamptz, timestamptz, timestamptz
) to authenticated;

-- 可选：自动确认邮箱（自建实例若已在 Auth 配置里开启可忽略）
-- update auth.users set email_confirmed_at = coalesce(email_confirmed_at, now()) where email_confirmed_at is null;

-- 授权：登录用户可读写自己的待办（RLS 仍会按 user_id 过滤）
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table public.todos to authenticated;
