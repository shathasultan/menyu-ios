-- منيو — أوقات الدوام، موقع المطعم، صور المنتجات

alter table public.restaurants
  add column if not exists opens_at text,      -- "HH:mm", بلا منطقة زمنية (وقت محلي للمطعم)
  add column if not exists closes_at text,     -- "HH:mm"
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

alter table public.menu_items
  add column if not exists image_url text;

insert into storage.buckets (id, name, public)
  values ('menu-images', 'menu-images', true)
  on conflict (id) do nothing;

drop policy if exists "public read menu images" on storage.objects;
create policy "public read menu images" on storage.objects
  for select using (bucket_id = 'menu-images');

drop policy if exists "authenticated upload menu images" on storage.objects;
create policy "authenticated upload menu images" on storage.objects
  for insert with check (bucket_id = 'menu-images' and auth.uid() is not null);

drop policy if exists "owners manage their menu images" on storage.objects;
create policy "owners manage their menu images" on storage.objects
  for update using (bucket_id = 'menu-images' and owner = auth.uid());

drop policy if exists "owners delete their menu images" on storage.objects;
create policy "owners delete their menu images" on storage.objects
  for delete using (bucket_id = 'menu-images' and owner = auth.uid());
