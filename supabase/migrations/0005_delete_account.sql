-- منيو — حذف الحساب الذاتي (يتطلبه Apple Guideline 5.1.1(v) لأي تطبيق فيه إنشاء حساب)
-- security definer: تعمل بصلاحية أعلى من صلاحية المستخدم العادي، لكنها مقيّدة بـauth.uid()
-- فلا يقدر أي مستخدم يحذف إلا صفّه هو بالضبط. حذف auth.users يُسقط تلقائيًا (cascade)
-- كل مطاعمه وتصنيفاته ومنتجاته لأن owner_id مربوطة بـon delete cascade أصلًا.

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = auth, public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_user() to authenticated;
