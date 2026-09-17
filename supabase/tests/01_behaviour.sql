\set QUIET on
\pset border 2
set client_min_messages = warning;

-- تنظيف بيانات الجولة السابقة
delete from public.menu_items; delete from public.menu_categories;
delete from storage.objects;
delete from public.restaurants;
update public.restaurants set next_category_index = 0;

insert into public.restaurants (id, owner_id, name, name_ar, next_category_index) values
 ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','A Cafe','مقهى أ',0),
 ('bbbbbbbb-0000-0000-0000-000000000002','22222222-2222-2222-2222-222222222222','B Cafe','مقهى ب',0);

create or replace function t_run(p_sql text, p_uid uuid, p_email text default null) returns text
language plpgsql as $f$
declare r text;
begin
  perform set_config('test.uid', coalesce(p_uid::text,''), true);
  perform set_config('test.email', coalesce(p_email,''), true);
  set local role authenticated;
  begin execute p_sql; r := 'OK'; exception when others then r := sqlstate; end;
  reset role; return r;
end $f$;

create or replace function t_val(p_sql text, p_uid uuid, p_email text default null) returns text
language plpgsql as $f$
declare r text;
begin
  perform set_config('test.uid', coalesce(p_uid::text,''), true);
  perform set_config('test.email', coalesce(p_email,''), true);
  set local role authenticated;
  begin execute p_sql into r; exception when others then r := sqlstate; end;
  reset role; return r;
end $f$;

create table t_results (n serial, label text, expected text, got text);
create or replace function t_check(l text, e text, g text) returns void
language sql as $$ insert into t_results(label,expected,got) values (l,e,g) $$;

-- ===== ١) الثغرة الأصلية =====
select t_check('التاجر يضبط status بنفسه','42501',
  t_run('update public.restaurants set status=''approved'' where id=''aaaaaaaa-0000-0000-0000-000000000001''',
        '11111111-1111-1111-1111-111111111111'));

select t_check('التاجر يكتب is_published','428C9',
  t_run('update public.restaurants set is_published=true where id=''aaaaaaaa-0000-0000-0000-000000000001''',
        '11111111-1111-1111-1111-111111111111'));

select t_check('التاجر ينقل الملكية','42501',
  t_run('update public.restaurants set owner_id=''22222222-2222-2222-2222-222222222222'' where id=''aaaaaaaa-0000-0000-0000-000000000001''',
        '11111111-1111-1111-1111-111111111111'));

-- ===== ٢) ما يجب أن ينجح =====
select t_check('التاجر يحفظ الاسم والجوال والعنوان','OK',
  t_run('update public.restaurants set name_ar=''مقهى أ الجديد'', phone=''0500000000'', address=''الرياض'' where id=''aaaaaaaa-0000-0000-0000-000000000001''',
        '11111111-1111-1111-1111-111111111111'));
select t_check('حُفظ الجوال فعلًا','0500000000',
  (select coalesce(phone,'(فارغ)') from public.restaurants where id='aaaaaaaa-0000-0000-0000-000000000001'));

-- ===== ٣) الترقيم =====
select t_check('التصنيف الأول A','A',
  t_val('select letter from public.add_category(''aaaaaaaa-0000-0000-0000-000000000001'',''Hot'',''ساخن'')',
        '11111111-1111-1111-1111-111111111111'));
select t_check('التصنيف الثاني B','B',
  t_val('select letter from public.add_category(''aaaaaaaa-0000-0000-0000-000000000001'',''Cold'',''بارد'')',
        '11111111-1111-1111-1111-111111111111'));
select t_run('delete from public.menu_categories where letter=''B''','11111111-1111-1111-1111-111111111111');
select t_check('بعد حذف B التالي C','C',
  t_val('select letter from public.add_category(''aaaaaaaa-0000-0000-0000-000000000001'',''New'',''جديد'')',
        '11111111-1111-1111-1111-111111111111'));

select t_check('المنتج الأول A01','A01',
  t_val('select code from public.add_item((select id from public.menu_categories where letter=''A''),''Espresso'',''اسبريسو'',10.5)',
        '11111111-1111-1111-1111-111111111111'));
select t_check('المنتج الثاني A02','A02',
  t_val('select code from public.add_item((select id from public.menu_categories where letter=''A''),''Latte'',''لاتيه'',14.5)',
        '11111111-1111-1111-1111-111111111111'));
select t_run('delete from public.menu_items where code=''A01''','11111111-1111-1111-1111-111111111111');
select t_check('بعد حذف A01 التالي A03','A03',
  t_val('select code from public.add_item((select id from public.menu_categories where letter=''A''),''Tea'',''شاي'',9)',
        '11111111-1111-1111-1111-111111111111'));
select t_check('display_order بلا تكرار','لا تكرار',
  (select case when count(*)=count(distinct display_order) then 'لا تكرار' else 'مكرر' end
     from public.menu_items));
select t_check('السعر الكسري محفوظ','14.50',
  (select coalesce((select price::text from public.menu_items where code='A02'),'(مفقود)')));
select t_check('التاجر يضيف تصنيفًا لمطعم غيره','42501',
  t_val('select letter from public.add_category(''bbbbbbbb-0000-0000-0000-000000000002'',''X'',''س'')',
        '11111111-1111-1111-1111-111111111111'));

-- ===== ٤) الأدمن =====
select t_check('is_admin لتاجر','false',
  t_val('select public.is_admin()::text','11111111-1111-1111-1111-111111111111','ownerA@test.sa'));
select t_check('is_admin للأدمن التجريبي','true',
  t_val('select public.is_admin()::text','33333333-3333-3333-3333-333333333333','demo.admin@menyu.sa'));
select t_check('تاجر ينادي set_restaurant_status','42501',
  t_run('select public.set_restaurant_status(''aaaaaaaa-0000-0000-0000-000000000001'',''approved'')',
        '11111111-1111-1111-1111-111111111111','ownerA@test.sa'));
select t_check('الأدمن يعتمد المطعم','OK',
  t_run('select public.set_restaurant_status(''aaaaaaaa-0000-0000-0000-000000000001'',''approved'')',
        '33333333-3333-3333-3333-333333333333','demo.admin@menyu.sa'));
select t_check('is_published تبع status','true',
  (select is_published::text from public.restaurants where id='aaaaaaaa-0000-0000-0000-000000000001'));
select t_check('الأدمن وحالة غير معروفة','22023',
  t_run('select public.set_restaurant_status(''aaaaaaaa-0000-0000-0000-000000000001'',''live'')',
        '33333333-3333-3333-3333-333333333333','demo.admin@menyu.sa'));

-- ===== ٥) ما يراه الزائر =====
select t_check('الزائر يرى المعتمد وحده','1', t_val('select count(*)::text from public.restaurants', null));
select t_check('الزائر يرى أصناف المعتمد','2', t_val('select count(*)::text from public.menu_items', null));
-- التاجر يرى مطعمه هو (غير معتمد) إضافة إلى المعتمد للجميع = 2
select t_check('التاجر يرى مطعمه غير المعتمد','2',
  t_val('select count(*)::text from public.restaurants','22222222-2222-2222-2222-222222222222','ownerB@test.sa'));
select t_check('ومطعمه هو ضمن ما يراه','pending',
  t_val('select status from public.restaurants where owner_id=''22222222-2222-2222-2222-222222222222''','22222222-2222-2222-2222-222222222222','ownerB@test.sa'));

-- ===== ٦) الصور =====
insert into storage.buckets(id,name,public) values ('menu-images','menu-images',true) on conflict do nothing;
select t_check('رفع داخل مجلد مطعمه','OK',
  t_run('insert into storage.objects(bucket_id,name,owner) values (''menu-images'',''aaaaaaaa-0000-0000-0000-000000000001/logo-1.jpg'',''11111111-1111-1111-1111-111111111111'')',
        '11111111-1111-1111-1111-111111111111'));
select t_check('رفع في مجلد مطعم غيره','42501',
  t_run('insert into storage.objects(bucket_id,name,owner) values (''menu-images'',''bbbbbbbb-0000-0000-0000-000000000002/x.jpg'',''11111111-1111-1111-1111-111111111111'')',
        '11111111-1111-1111-1111-111111111111'));
select t_check('رفع في جذر الحاوية','42501',
  t_run('insert into storage.objects(bucket_id,name,owner) values (''menu-images'',''anything.jpg'',''11111111-1111-1111-1111-111111111111'')',
        '11111111-1111-1111-1111-111111111111'));

-- ===== ٧) قيدا التفرّد =====
select t_check('قيد تفرّد الحرف','23505',
  t_run('insert into public.menu_categories(restaurant_id,letter,name,name_ar) values (''aaaaaaaa-0000-0000-0000-000000000001'',''A'',''dup'',''مكرر'')',
        '11111111-1111-1111-1111-111111111111'));
select t_check('الفهرسان موجودان','2',
  (select count(*)::text from pg_indexes where indexname in ('uq_categories_restaurant_letter','uq_items_category_code')));

\echo ''
select n as "#", label as "الفحص", expected as "المتوقَّع", got as "الناتج",
       case when expected=got then 'PASS' else 'FAIL' end as "النتيجة"
from t_results order by n;
select count(*) filter (where expected=got) as "ناجح", count(*) filter (where expected<>got) as "فاشل" from t_results;
