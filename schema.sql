-- FamilyFit v2: run in a NEW Supabase project SQL editor.
create extension if not exists pgcrypto;
create table public.families(id uuid primary key default gen_random_uuid(), surname text not null, organizer uuid not null references auth.users(id), created_at timestamptz default now());
create table public.members(user_id uuid primary key references auth.users(id) on delete cascade, family_id uuid not null references public.families(id) on delete cascade, first_name text not null check(length(first_name) between 1 and 50), role text not null check(role in ('organizer','adult','child')), created_at timestamptz default now());
create table public.invites(id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade, code_hash text not null unique, role text not null check(role in ('adult','child')), created_by uuid not null references auth.users(id), expires_at timestamptz not null default now()+interval '7 days', redeemed_by uuid unique references auth.users(id), created_at timestamptz default now());
create table public.entries(id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, category text not null check(category in ('steps','workout','water','weight','height','food')), amount numeric(12,2) check(amount>=0 and amount<=1000000), description text check(length(description)<=160), food_id uuid, entry_date date not null default current_date, created_at timestamptz default now());
create table public.foods(id uuid primary key default gen_random_uuid(), owner_id uuid references auth.users(id) on delete cascade, name text not null check(length(name) between 1 and 100), ingredients text, serving text not null, calories numeric not null check(calories between 0 and 10000), protein numeric not null check(protein between 0 and 1000), carbs numeric not null check(carbs between 0 and 1000), fat numeric not null check(fat between 0 and 1000), created_at timestamptz default now());
alter table public.entries add constraint entries_food_fk foreign key(food_id) references public.foods(id) on delete set null;
create index entries_user_date on public.entries(user_id,entry_date desc);
create index foods_owner on public.foods(owner_id);
-- RLS: family directory shows names and roles ONLY, never private health information.
alter table public.families enable row level security;
alter table public.members enable row level security;
alter table public.invites enable row level security;
alter table public.entries enable row level security;
alter table public.foods enable row level security;
create policy family_view on public.families for select to authenticated using(exists(select 1 from public.members m where m.family_id=id and m.user_id=(select auth.uid())));
create policy member_view on public.members for select to authenticated using(family_id=(select m.family_id from public.members m where m.user_id=(select auth.uid())));
create policy entry_view on public.entries for select to authenticated using(user_id=(select auth.uid()));
create policy entry_add on public.entries for insert to authenticated with check(user_id=(select auth.uid()) and (category not in ('weight','height') or exists(select 1 from public.members m where m.user_id=(select auth.uid()) and m.role<>'child')) and (category<>'food' or food_id is not null));
create policy entry_delete on public.entries for delete to authenticated using(user_id=(select auth.uid()));
create policy foods_view on public.foods for select to authenticated using(owner_id=(select auth.uid()) or owner_id is null);
create policy foods_add on public.foods for insert to authenticated with check(owner_id=(select auth.uid()));
create policy foods_delete on public.foods for delete to authenticated using(owner_id=(select auth.uid()));
-- Functions are SECURITY DEFINER to safely perform invitation onboarding. Never expose invite rows.
create or replace function public.create_family(p_surname text,p_first_name text) returns void language plpgsql security definer set search_path='' as $$
declare fid uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if exists(select 1 from public.members where user_id=auth.uid()) then raise exception 'Already in a family'; end if;
 if lower(trim(p_surname)) <> 'homsi' or lower(trim(p_first_name)) <> 'yaman' then raise exception 'Only Yaman may initialize the Homsi family'; end if;
 insert into public.families(surname,organizer) values(trim(p_surname),auth.uid()) returning id into fid;
 insert into public.members(user_id,family_id,first_name,role) values(auth.uid(),fid,trim(p_first_name),'organizer');
end $$;
create or replace function public.make_invite(p_role text,p_code text) returns void language plpgsql security definer set search_path='' as $$
declare fid uuid;
begin
 select family_id into fid from public.members where user_id=auth.uid() and role='organizer';
 if fid is null then raise exception 'Only the family organizer can invite'; end if;
 if p_role not in ('adult','child') or length(p_code)<24 then raise exception 'Invalid invitation'; end if;
 insert into public.invites(family_id,code_hash,role,created_by) values(fid,encode(extensions.digest(p_code,'sha256'),'hex'),p_role,auth.uid());
end $$;
create or replace function public.join_family(p_first_name text,p_code text) returns void language plpgsql security definer set search_path='' as $$
declare inv record;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if exists(select 1 from public.members where user_id=auth.uid()) then raise exception 'Already in a family'; end if;
 if lower(trim(p_first_name)) not in ('yaman','lama','wassim','talya') then raise exception 'Not an approved profile'; end if;
 select * into inv from public.invites where code_hash=encode(extensions.digest(p_code,'sha256'),'hex') and redeemed_by is null and expires_at>now() for update;
 if not found then raise exception 'Invalid or expired invitation'; end if;
 update public.invites set redeemed_by=auth.uid() where id=inv.id;
 insert into public.members(user_id,family_id,first_name,role) values(auth.uid(),inv.family_id,trim(p_first_name),inv.role);
end $$;
revoke all on function public.create_family(text,text),public.make_invite(text,text),public.join_family(text,text) from public;
grant execute on function public.create_family(text,text),public.make_invite(text,text),public.join_family(text,text) to authenticated;
-- Prevent a child from writing weight entries via direct API requests.
create or replace function public.check_entry() returns trigger language plpgsql set search_path='' as $$
begin
 if new.user_id <> auth.uid() then raise exception 'Not your entry'; end if;
 if new.category in ('weight','height') and exists(select 1 from public.members where user_id=new.user_id and role='child') then raise exception 'Weight logging is not available for children'; end if;
 if new.category='food' and not exists(select 1 from public.foods where id=new.food_id and (owner_id=new.user_id or owner_id is null)) then raise exception 'Food not accessible'; end if;
 return new;
end $$;
create trigger validate_entry before insert or update on public.entries for each row execute function public.check_entry();
-- No unrestricted update policies are defined.

-- IMPORTANT: Run this in a NEW project only. Yaman's first account must be
-- created under your control before inviting anyone. See README.
-- The following RPC checks organizer role server-side; never grants health access.
create or replace function public.admin_revoke_member(p_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare admin_family uuid;
begin
 select family_id into admin_family from public.members where user_id=auth.uid() and role='organizer';
 if admin_family is null then raise exception 'Admin only'; end if;
 if p_user_id=auth.uid() then raise exception 'Cannot revoke your own admin access'; end if;
 delete from public.members where user_id=p_user_id and family_id=admin_family and role<>'organizer';
end $$;
revoke all on function public.admin_revoke_member(uuid) from public;
grant execute on function public.admin_revoke_member(uuid) to authenticated;
