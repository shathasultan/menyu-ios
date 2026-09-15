-- منيو — حساب إدارة تجريبي إلى جانب حساب الإدارة الأساسي.
--
-- سياستا 0002 كانتا مربوطتين ببريد واحد مكتوب يدويًا، فلا يستطيع أحد تجربة
-- دور الإدارة إلا بالدخول بحساب المالكة نفسه. هنا نوسّعهما إلى قائمة، حتى
-- يجرّب الفريق المراجعة والاعتماد بحساب خاص بهم دون مشاركة حساب شخصي.
--
-- هذا حل مؤقت مقصود: الوجهة الصحيحة جدول أدوار حقيقي، كما يقول التعليق في
-- AppStore.swift. عند إضافة الأدمن الثالث، يُستبدل هذا بجدول.

drop policy if exists "admin full read" on public.restaurants;
create policy "admin full read" on public.restaurants
  for select using (
    (auth.jwt() ->> 'email') in ('shathasultann9@gmail.com', 'demo.admin@menyu.sa')
  );

drop policy if exists "admin full update" on public.restaurants;
create policy "admin full update" on public.restaurants
  for update using (
    (auth.jwt() ->> 'email') in ('shathasultann9@gmail.com', 'demo.admin@menyu.sa')
  );
