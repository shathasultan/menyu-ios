-- منيو — الإدارة تشوف قائمة المطعم قبل ما تعتمده
--
-- المشكلة: تجاوز الإدارة في 0002/0007 كان على جدول restaurants وحده، بينما
-- سياستا القراءة على menu_categories و menu_items تشترطان أن يكون المطعم
-- منشورًا أو مملوكًا للمستخدم. والمطعم قيد المراجعة لا هذا ولا ذاك، فترجع
-- قائمته فاضية للإدارة — تعتمد مطعمًا دون أن ترى منتجًا واحدًا منه، وتظهر
-- كل طلباتها بعدّاد «٠ منتج» في AdminReviewView.
--
-- ومعها: البريد المكتوب يدويًا كان مكرَّرًا في كل سياسة، فأي أدمن جديد يعني
-- تعديل أربع سياسات. صار الآن في دالة واحدة.

create or replace function public.is_menyu_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (auth.jwt() ->> 'email') in ('shathasultann9@gmail.com', 'demo.admin@menyu.sa'),
    false
  )
$$;

-- anon أيضًا، لا authenticated وحده: السياسات أدناه بلا TO، فتُقيَّم لكل الأدوار.
-- الزبون يتصفّح بلا حساب (كما تقول شاشة AccountView صراحةً)، فلو لم يملك anon
-- صلاحية التنفيذ لفشل كل استعلام قائمة بـ«permission denied for function».
grant execute on function public.is_menyu_admin() to anon, authenticated;

-- restaurants: نفس التجاوز السابق، لكن عبر الدالة
drop policy if exists "admin full read" on public.restaurants;
create policy "admin full read" on public.restaurants
  for select using (public.is_menyu_admin());

drop policy if exists "admin full update" on public.restaurants;
create policy "admin full update" on public.restaurants
  for update using (public.is_menyu_admin());

-- التصنيفات والمنتجات: قراءة فقط. الإدارة تراجع وتعتمد، ولا تحرّر قائمة أحد.
drop policy if exists "admin read all categories" on public.menu_categories;
create policy "admin read all categories" on public.menu_categories
  for select using (public.is_menyu_admin());

drop policy if exists "admin read all items" on public.menu_items;
create policy "admin read all items" on public.menu_items
  for select using (public.is_menyu_admin());
