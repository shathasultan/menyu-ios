-- منيو — فحص ما بعد 0008. للقراءة فقط: لا يكتب شيئًا ولا يغيّر شيئًا.
-- شغّليه في Supabase → SQL Editor بعد تشغيل 0008، واقرئي عمود result:
-- كل سطر إما PASS أو FAIL مع سبب. أي FAIL يعني أن التطبيق سيفشل عند تلك النقطة.

with checks as (

  -- ١) is_published صار عمودًا مولَّدًا، فلا يمكن للتطبيق كتابته إطلاقًا
  select 1 as n, 'is_published عمود مولَّد' as check_name,
    case when exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='restaurants'
        and column_name='is_published' and is_generated='ALWAYS'
    ) then 'PASS' else 'FAIL — لم تُشغَّل 0008، أو العمود ما زال عاديًّا' end as result

  -- ٢) التاجر لا يملك صلاحية الكتابة على status ولا owner_id
  union all select 2, 'status وowner_id ممنوعان على authenticated',
    case when not exists (
      select 1 from information_schema.column_privileges
      where table_schema='public' and table_name='restaurants'
        and grantee='authenticated' and privilege_type='UPDATE'
        and column_name in ('status','owner_id')
    ) then 'PASS' else 'FAIL — التاجر ما زال يقدر ينشر نفسه' end

  -- ٣) الأعمدة التي يحتاجها التاجر فعلًا ما زالت مسموحة
  union all select 3, 'أعمدة التاجر المسموحة',
    case when (
      select count(distinct column_name) from information_schema.column_privileges
      where table_schema='public' and table_name='restaurants'
        and grantee='authenticated' and privilege_type='UPDATE'
        and column_name in ('name','name_ar','opens_at','closes_at','latitude',
                            'longitude','image_url','phone','address','next_category_index')
    ) = 10 then 'PASS' else 'FAIL — نقصت صلاحية عمود، فالحفظ سيُرفض' end

  -- ٤) سياسة التحديث صار لها with check
  union all select 4, 'with check على تحديث المطاعم',
    case when exists (
      select 1 from pg_policies
      where schemaname='public' and tablename='restaurants'
        and policyname='owners update their restaurants' and with_check is not null
    ) then 'PASS' else 'FAIL — نقل الملكية ما زال ممكنًا' end

  -- ٥) الدوال الأربع موجودة (التطبيق ينادي كل واحدة منها)
  union all select 5, 'دوال القاعدة الأربع',
    case when (
      select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname in
        ('is_admin','set_restaurant_status','add_category','add_item')
    ) >= 4 then 'PASS' else 'FAIL — التطبيق سيفشل عند الإضافة أو الاعتماد' end

  -- ٦) عمودا بيانات المتجر اللذان كانت الشاشة تجمعهما ولا تحفظهما
  union all select 6, 'عمودا phone وaddress',
    case when (
      select count(*) from information_schema.columns
      where table_schema='public' and table_name='restaurants' and column_name in ('phone','address')
    ) = 2 then 'PASS' else 'FAIL — «حفظ بيانات المتجر» سيفشل' end

  -- ٧) سياسات الحاوية صارت مربوطة بمجلد المطعم
  union all select 7, 'سياسات حاوية الصور',
    case when (
      select count(*) from pg_policies
      where schemaname='storage' and tablename='objects'
        and policyname in ('owners upload their menu images',
                           'owners update their menu images',
                           'owners delete their menu images')
    ) = 3 then 'PASS' else 'FAIL — الرفع ما زال مفتوحًا لأي مسار' end

  -- ٨) السياسات القديمة المرتبطة ببريد مكتوب يدويًّا اختفت
  union all select 8, 'سياستا الأدمن القديمتان أُزيلتا',
    case when not exists (
      select 1 from pg_policies
      where schemaname='public' and tablename='restaurants'
        and policyname in ('admin full read','admin full update')
    ) then 'PASS' else 'FAIL' end

  -- ٩) جدول الأدمن فيه البريدان
  union all select 9, 'app_admins فيه البريدان',
    case when (
      select count(*) from public.app_admins
      where email in ('shathasultann9@gmail.com','demo.admin@menyu.sa')
    ) = 2 then 'PASS' else 'FAIL — أضيفي البريد الناقص إلى app_admins' end

  -- ١٠) حساب الأدمن التجريبي موجود فعلًا في auth، وليس في جدول الأدمن فقط.
  --     هذه أكثر نقطة يُتوقع أن تفشل: 0007 و0008 يمنحان الصلاحية لبريد،
  --     لكن لا أحد منهما ينشئ المستخدم نفسه.
  union all select 10, 'مستخدم demo.admin@menyu.sa موجود في auth',
    case when exists (
      select 1 from auth.users where email='demo.admin@menyu.sa'
    ) then 'PASS' else 'FAIL — أنشئيه من Authentication → Users → Add user، '
                       || 'وفعّلي Auto Confirm، فشاشة الأدمن تدخل ببريد وكلمة مرور' end

  -- ١١) وله كلمة مرور. الدخول من شاشة الأدمن بالبريد وكلمة المرور،
  --     فحساب أُنشئ بقوقل وحده لن يدخل منها.
  union all select 11, 'لـdemo.admin كلمة مرور قابلة للدخول',
    case when exists (
      select 1 from auth.users
      where email='demo.admin@menyu.sa'
        and encrypted_password is not null and encrypted_password <> ''
        and email_confirmed_at is not null
    ) then 'PASS' else 'FAIL — إما بلا كلمة مرور أو البريد غير مؤكَّد' end

  -- ١٢) حساب المالكة أيضًا: إن كان بقوقل فقط فلن يدخل من شاشة الأدمن
  union all select 12, 'حساب المالكة يدخل من شاشة الأدمن',
    case when exists (
      select 1 from auth.users
      where email='shathasultann9@gmail.com'
        and encrypted_password is not null and encrypted_password <> ''
    ) then 'PASS'
    when exists (select 1 from auth.users where email='shathasultann9@gmail.com')
      then 'FAIL — الحساب موجود بقوقل بلا كلمة مرور: اضبطي كلمة مرور له، '
           || 'أو ادخلي بحساب الأدمن التجريبي'
    else 'FAIL — لا يوجد مستخدم بهذا البريد بعد' end

  -- ١٣) لا يوجد صفّ تفارق فيه العمودان (يستحيل بعد ٱلمولَّد، وهذا تأكيد)
  union all select 13, 'لا تفارق بين status وis_published',
    case when not exists (
      select 1 from public.restaurants where is_published <> (status='approved')
    ) then 'PASS' else 'FAIL' end

  -- ١٤) قيدا التفرّد اللذان يمسكان تكرار الرموز
  union all select 14, 'قيدا تفرّد الرموز',
    case when (
      select count(*) from pg_indexes where schemaname='public'
        and indexname in ('uq_categories_restaurant_letter','uq_items_category_code')
    ) = 2 then 'PASS' else 'FAIL — يوجد تكرار قديم منع إنشاءهما؛ نظّفيه بالاستعلامين أسفل الملف' end
)
select check_name, result from checks order by n;

-- إن فشل الفحص ١٤، هذان الاستعلامان يعرضان التكرار الذي يمنع القيد:
--
-- select restaurant_id, letter, count(*) from public.menu_categories
--   group by 1,2 having count(*) > 1;
-- select category_id, code, count(*) from public.menu_items
--   group by 1,2 having count(*) > 1;
