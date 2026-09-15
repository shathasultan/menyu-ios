-- منيو — الصور تُربط بمالكها الحقيقي
--
-- المشكلة: سياسة 0003 كانت «أي مستخدم مسجّل يرفع في هذا الدلو»:
--   for insert with check (bucket_id = 'menu-images' and auth.uid() is not null)
-- ومسار الصورة مشتق من المعرّف: '<item_id>.jpg' و 'restaurant-<id>.jpg'.
-- ومعرّفات المنتجات مقروءة للعامة عبر الـAPI. فأي تاجر مسجّل يقدر يقرأ معرّف
-- منتج في مطعم غيره ويرفع فوق صورته (upsert مفعّل في AppStore) — أو يملأ
-- الدلو العام بملفات لا علاقة لها بالتطبيق.
--
-- الحل: تُشتق الصلاحية من الملكية الفعلية للصف المقابل للمسار.
--
-- ترتيب العمليات في AppStore يوافق هذا: الحذف يمسح الصور أولًا ثم الصف،
-- فالصف ما زال موجودًا لحظة التحقق (deleteItem / deleteCategory /
-- deleteRestaurant / deleteAccount كلها بهذا الترتيب).

create or replace function public.owns_menu_image(object_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when object_name like 'restaurant-%' then exists (
      select 1 from public.restaurants r
       where r.owner_id = auth.uid()
         and object_name = 'restaurant-' || r.id::text || '.jpg'
    )
    else exists (
      select 1
        from public.menu_items i
        join public.menu_categories c on c.id = i.category_id
        join public.restaurants r on r.id = c.restaurant_id
       where r.owner_id = auth.uid()
         and object_name = i.id::text || '.jpg'
    )
  end
$$;

grant execute on function public.owns_menu_image(text) to authenticated;

-- الرفع: للمالك وحده، وعلى مسار يخصّ صفًّا يملكه
drop policy if exists "authenticated upload menu images" on storage.objects;
drop policy if exists "owners upload their menu images" on storage.objects;
create policy "owners upload their menu images" on storage.objects
  for insert with check (
    bucket_id = 'menu-images' and public.owns_menu_image(name)
  );

-- الاستبدال: upsert في Supabase Storage يمرّ على INSERT و UPDATE معًا،
-- فالشرط نفسه لازم على الاثنين. السياسة القديمة كانت على owner = auth.uid()
-- وهو عمود الرافع الأول لا مالك المطعم، فتنكسر لو رُفعت الصورة من جلسة أخرى.
drop policy if exists "owners manage their menu images" on storage.objects;
drop policy if exists "owners update their menu images" on storage.objects;
create policy "owners update their menu images" on storage.objects
  for update using (
    bucket_id = 'menu-images' and public.owns_menu_image(name)
  ) with check (
    bucket_id = 'menu-images' and public.owns_menu_image(name)
  );

drop policy if exists "owners delete their menu images" on storage.objects;
create policy "owners delete their menu images" on storage.objects
  for delete using (
    bucket_id = 'menu-images' and public.owns_menu_image(name)
  );

-- القراءة العامة تبقى كما هي (الدلو عام والقوائم معروضة للزبائن).
