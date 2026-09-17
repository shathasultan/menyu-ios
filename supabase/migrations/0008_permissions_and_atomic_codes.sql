-- منيو — أساس الصلاحيات: لا نشر ذاتي، ولا مصدرَي حقيقة، ولا رموز متسابقة.
-- شغّليه في: Supabase Dashboard → SQL Editor → New query → الصق ونفّذ (Run).
--
-- ما يعالجه هذا الملف:
--   ١. سياسة تحديث المطاعم كانت بلا with check، فكان صاحب المطعم يقدر ينشر
--      نفسه (is_published/status) ويغيّر owner_id — أي يتجاوز مراجعة 0002 كلها.
--   ٢. is_published وstatus عمودان يحدّثهما التطبيق يدويًّا معًا فيتفارقان.
--   ٣. ترقيم الرموز كان قراءة ثم كتابة من التطبيق، فإضافتان متزامنتان تنتجان
--      رمزين متكررين.
--   ٤. بريد الأدمن مكتوب داخل السياسات، ومكرّر في كود التطبيق.
--   ٥. أي مستخدم مسجَّل كان يرفع في حاوية الصور بأي مسار.

-- ========== ١) جدول أدمن حقيقي بدل البريد المكتوب في السياسة ==========

create table if not exists public.app_admins (
  email text primary key,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;
-- بلا سياسة: لا يقرأه أحد من العميل إطلاقًا، يُقرأ فقط داخل is_admin() أدناه.

insert into public.app_admins (email) values
  ('shathasultann9@gmail.com'),
  ('demo.admin@menyu.sa')
on conflict (email) do nothing;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.app_admins a where a.email = (auth.jwt() ->> 'email')
  );
$$;

grant execute on function public.is_admin() to authenticated, anon;

-- ========== ٢) status مصدر الحقيقة الوحيد، وis_published مشتق منه ==========

-- تُسقَط أولًا السياسات التي تشير إلى is_published، وإلا رفض Postgres حذف العمود.
drop policy if exists "public read published restaurants" on public.restaurants;
drop policy if exists "public read categories of visible restaurants" on public.menu_categories;
drop policy if exists "public read items of visible restaurants" on public.menu_items;

-- مواءمة أي صفّ تفارق فيه العمودان قبل الاعتماد على status وحده.
update public.restaurants set status = 'approved' where is_published and status <> 'approved';
update public.restaurants set status = 'pending'  where not is_published and status = 'approved';

alter table public.restaurants drop column is_published;
alter table public.restaurants
  add column is_published boolean generated always as (status = 'approved') stored;

-- ========== ٣) بيانات المتجر التي كانت تُكتب في الشاشة ولا تُحفظ ==========

alter table public.restaurants
  add column if not exists phone text,
  add column if not exists address text;

-- ========== ٤) إعادة بناء سياسات القراءة على status ==========

create policy "public read published restaurants" on public.restaurants
  for select using (
    status = 'approved' or auth.uid() = owner_id or public.is_admin()
  );

create policy "public read categories of visible restaurants" on public.menu_categories
  for select using (
    exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id
        and (r.status = 'approved' or r.owner_id = auth.uid() or public.is_admin())
    )
  );

create policy "public read items of visible restaurants" on public.menu_items
  for select using (
    exists (
      select 1 from public.menu_categories c
      join public.restaurants r on r.id = c.restaurant_id
      where c.id = category_id
        and (r.status = 'approved' or r.owner_id = auth.uid() or public.is_admin())
    )
  );

-- ========== ٥) سياسات الكتابة: with check على كل تحديث ==========
-- using يحدّد أي الصفوف تُعدَّل، وwith check يحدّد القيمة الجديدة المسموحة.
-- غيابه هو ما سمح بنقل owner_id إلى حساب آخر.

drop policy if exists "owners insert their restaurants" on public.restaurants;
create policy "owners insert their restaurants" on public.restaurants
  for insert with check (auth.uid() = owner_id);

drop policy if exists "owners update their restaurants" on public.restaurants;
create policy "owners update their restaurants" on public.restaurants
  for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "owners delete their restaurants" on public.restaurants;
create policy "owners delete their restaurants" on public.restaurants
  for delete using (auth.uid() = owner_id);

-- سياستا الأدمن القديمتان لم تعودا لازمتين: القراءة دخلت في سياسة القراءة أعلاه،
-- والتحديث صار عبر set_restaurant_status وحدها.
drop policy if exists "admin full read" on public.restaurants;
drop policy if exists "admin full update" on public.restaurants;

-- ========== ٦) صلاحيات على مستوى العمود: مفتاح النشر ليس بيد التاجر ==========
-- with check وحده يمنع نقل الملكية، لكنه لا يمنع المالك من ضبط status لنفسه.
-- المنع الحقيقي هنا: لا يملك أصلًا صلاحية الكتابة على هذا العمود.

revoke update on public.restaurants from authenticated;
grant update (
  name, name_ar, type, description_en, description_ar,
  opens_at, closes_at, latitude, longitude, image_url,
  phone, address, next_category_index
) on public.restaurants to authenticated;

revoke insert, update, delete on public.restaurants     from anon;
revoke insert, update, delete on public.menu_categories from anon;
revoke insert, update, delete on public.menu_items      from anon;

-- ========== ٧) تغيير الحالة: للأدمن وحده، ومصدر حقيقة واحد ==========

create or replace function public.set_restaurant_status(p_restaurant_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_found uuid;
begin
  if not public.is_admin() then
    raise exception 'ليست لديك صلاحية الإدارة' using errcode = '42501';
  end if;
  if p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'حالة غير معروفة: %', p_status using errcode = '22023';
  end if;

  update public.restaurants set status = p_status
   where id = p_restaurant_id
  returning id into v_found;

  if v_found is null then
    raise exception 'لا يوجد مطعم بهذا المعرّف' using errcode = 'P0002';
  end if;
end;
$$;

grant execute on function public.set_restaurant_status(uuid, text) to authenticated;

-- ========== ٨) ترقيم ذرّي للتصنيفات والمنتجات ==========
-- security invoker: تبقى RLS نافذة داخل الدالة، فلا تفتح بابًا جانبيًّا.
-- update ... returning يقفل الصف، فإضافتان متزامنتان تتسلسلان بدل أن تتسابقا.
-- display_order يُحسب من max+1 لا من count، فلا يتكرّر بعد أي حذف.

create or replace function public.add_category(p_restaurant_id uuid, p_name text, p_name_ar text)
returns public.menu_categories
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_index integer;
  v_order integer;
  c public.menu_categories;
begin
  update public.restaurants
     set next_category_index = next_category_index + 1
   where id = p_restaurant_id
  returning next_category_index - 1 into v_index;

  if v_index is null then
    raise exception 'لا يمكنك الإضافة لهذا المطعم' using errcode = '42501';
  end if;
  if v_index > 25 then
    raise exception 'بلغت الحد الأقصى ٢٦ تصنيفًا' using errcode = '22023';
  end if;

  select coalesce(max(display_order) + 1, 0) into v_order
    from public.menu_categories where restaurant_id = p_restaurant_id;

  insert into public.menu_categories (restaurant_id, letter, name, name_ar, display_order)
  values (p_restaurant_id, chr(65 + v_index), p_name, p_name_ar, v_order)
  returning * into c;

  return c;
end;
$$;

grant execute on function public.add_category(uuid, text, text) to authenticated;

create or replace function public.add_item(p_category_id uuid, p_name text, p_name_ar text, p_price numeric)
returns public.menu_items
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_number integer;
  v_letter text;
  v_order  integer;
  i public.menu_items;
begin
  update public.menu_categories
     set next_item_number = next_item_number + 1
   where id = p_category_id
  returning next_item_number - 1, letter into v_number, v_letter;

  if v_number is null then
    raise exception 'لا يمكنك الإضافة لهذا التصنيف' using errcode = '42501';
  end if;

  select coalesce(max(display_order) + 1, 0) into v_order
    from public.menu_items where category_id = p_category_id;

  insert into public.menu_items (category_id, code, name, name_ar, price, display_order)
  values (p_category_id, v_letter || to_char(v_number, 'FM00'), p_name, p_name_ar,
          coalesce(p_price, 0), v_order)
  returning * into i;

  return i;
end;
$$;

grant execute on function public.add_item(uuid, text, text, numeric) to authenticated;

-- ========== ٩) حاوية الصور: المسار مملوك ==========
-- المسار الجديد: {restaurant_id}/{item_id}-{نسخة}.jpg وللشعار {restaurant_id}/logo-{نسخة}.jpg
-- الاسم متغيّر في كل رفع، فينتهي أيضًا تعليق الصورة القديمة في الكاش ساعةً كاملة.
-- ملاحظة: الصور القديمة في جذر الحاوية ({item_id}.jpg) تبقى ظاهرة للعملاء
-- لأن القراءة عامة، لكن حذفها لم يعد ممكنًا من التطبيق — تُنظَّف يدويًّا من اللوحة.

drop policy if exists "authenticated upload menu images" on storage.objects;
drop policy if exists "owners manage their menu images" on storage.objects;
drop policy if exists "owners delete their menu images" on storage.objects;

-- `storage.objects.name` مؤهَّل عمدًا: بدون التأهيل يحلّ Postgres اسم العمود
-- داخل الاستعلام الفرعي على أقرب نطاق، وهو public.restaurants.name — أي اسم
-- المطعم بدل اسم الملف. الشرط حينها لا يتحقق أبدًا فيُرفض كل رفع صورة.

create policy "owners upload their menu images" on storage.objects
  for insert with check (
    bucket_id = 'menu-images'
    and exists (
      select 1 from public.restaurants r
      where r.owner_id = auth.uid()
        and r.id::text = (storage.foldername(storage.objects.name))[1]
    )
  );

create policy "owners update their menu images" on storage.objects
  for update using (
    bucket_id = 'menu-images'
    and exists (
      select 1 from public.restaurants r
      where r.owner_id = auth.uid()
        and r.id::text = (storage.foldername(storage.objects.name))[1]
    )
  );

create policy "owners delete their menu images" on storage.objects
  for delete using (
    bucket_id = 'menu-images'
    and exists (
      select 1 from public.restaurants r
      where r.owner_id = auth.uid()
        and r.id::text = (storage.foldername(storage.objects.name))[1]
    )
  );

-- ========== ١٠) قيدا تفرّد يمسكان أي تكرار بقي من السباق القديم ==========
-- داخل DO حتى لا يُسقط الملفَّ كلَّه لو وُجد تكرار سابق في البيانات الحية؛
-- إن ظهر الإشعار، نظّفي التكرار ثم أعيدي إنشاء الفهرس وحده.

do $$
begin
  create unique index uq_categories_restaurant_letter
    on public.menu_categories(restaurant_id, letter);
exception
  when duplicate_table then null;
  when others then raise notice 'تعذّر إنشاء uq_categories_restaurant_letter: %', sqlerrm;
end $$;

do $$
begin
  create unique index uq_items_category_code
    on public.menu_items(category_id, code);
exception
  when duplicate_table then null;
  when others then raise notice 'تعذّر إنشاء uq_items_category_code: %', sqlerrm;
end $$;
