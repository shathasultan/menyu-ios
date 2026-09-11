-- منيو — المخطط الأساسي (restaurants / menu_categories / menu_items)
-- شغّليه في: Supabase Dashboard → SQL Editor → New query → الصق ونفّذ (Run).
-- هذا المخطط مطابق تمامًا لما يستعلمه AppStore.swift/DBModels.swift في التطبيق.

create extension if not exists pgcrypto;

-- ========== restaurants ==========
create table if not exists public.restaurants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  name_ar text not null,
  type text not null default 'restaurant',
  description_en text not null default '',
  description_ar text not null default '',
  next_category_index integer not null default 0,
  is_published boolean not null default true,
  created_at timestamptz not null default now()
);

-- ========== menu_categories ==========
create table if not exists public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  letter text not null,
  name text not null,
  name_ar text not null,
  display_order integer not null default 0,
  next_item_number integer not null default 1,
  created_at timestamptz not null default now()
);

-- ========== menu_items ==========
create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.menu_categories(id) on delete cascade,
  code text not null,
  name text not null,
  name_ar text not null,
  price numeric(10,2) not null default 0,
  is_available boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_restaurants_owner on public.restaurants(owner_id);
create index if not exists idx_categories_restaurant on public.menu_categories(restaurant_id);
create index if not exists idx_items_category on public.menu_items(category_id);

-- ========== Row Level Security ==========
alter table public.restaurants enable row level security;
alter table public.menu_categories enable row level security;
alter table public.menu_items enable row level security;

-- restaurants: أي زائر يقرأ المطاعم المنشورة، والمالك يقرأ مطاعمه كلها (منشورة أو لا)
drop policy if exists "public read published restaurants" on public.restaurants;
create policy "public read published restaurants" on public.restaurants
  for select using (is_published = true or auth.uid() = owner_id);

drop policy if exists "owners insert their restaurants" on public.restaurants;
create policy "owners insert their restaurants" on public.restaurants
  for insert with check (auth.uid() = owner_id);

drop policy if exists "owners update their restaurants" on public.restaurants;
create policy "owners update their restaurants" on public.restaurants
  for update using (auth.uid() = owner_id);

drop policy if exists "owners delete their restaurants" on public.restaurants;
create policy "owners delete their restaurants" on public.restaurants
  for delete using (auth.uid() = owner_id);

-- menu_categories: القراءة العامة تتبع حالة نشر المطعم، والإدارة الكاملة لمالك المطعم فقط
drop policy if exists "public read categories of visible restaurants" on public.menu_categories;
create policy "public read categories of visible restaurants" on public.menu_categories
  for select using (
    exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and (r.is_published = true or r.owner_id = auth.uid())
    )
  );

drop policy if exists "owners manage their categories" on public.menu_categories;
create policy "owners manage their categories" on public.menu_categories
  for all using (
    exists (select 1 from public.restaurants r where r.id = restaurant_id and r.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.restaurants r where r.id = restaurant_id and r.owner_id = auth.uid())
  );

-- menu_items: نفس المنطق عبر التصنيف ثم المطعم
drop policy if exists "public read items of visible restaurants" on public.menu_items;
create policy "public read items of visible restaurants" on public.menu_items
  for select using (
    exists (
      select 1 from public.menu_categories c
      join public.restaurants r on r.id = c.restaurant_id
      where c.id = category_id and (r.is_published = true or r.owner_id = auth.uid())
    )
  );

drop policy if exists "owners manage their items" on public.menu_items;
create policy "owners manage their items" on public.menu_items
  for all using (
    exists (
      select 1 from public.menu_categories c
      join public.restaurants r on r.id = c.restaurant_id
      where c.id = category_id and r.owner_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.menu_categories c
      join public.restaurants r on r.id = c.restaurant_id
      where c.id = category_id and r.owner_id = auth.uid()
    )
  );
