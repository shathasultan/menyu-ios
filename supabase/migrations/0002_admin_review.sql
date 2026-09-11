-- منيو — مراجعة يدوية قبل النشر (نمط هنقر ستيشن): كل مطعم جديد يبدأ غير منشور
-- حتى تعتمده الإدارة، بدل النشر الفوري الذاتي.

-- مطاعم جديدة تبدأ غير منشورة افتراضيًا
alter table public.restaurants alter column is_published set default false;

-- تجاوز إداري: الحساب المعتمَد وحده يقرأ/يحدّث كل المطاعم بلا استثناء owner_id
drop policy if exists "admin full read" on public.restaurants;
create policy "admin full read" on public.restaurants
  for select using ((auth.jwt() ->> 'email') = 'shathasultann9@gmail.com');

drop policy if exists "admin full update" on public.restaurants;
create policy "admin full update" on public.restaurants
  for update using ((auth.jwt() ->> 'email') = 'shathasultann9@gmail.com');
