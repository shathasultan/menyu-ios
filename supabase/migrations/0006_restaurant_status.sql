-- منيو — تمييز "مرفوض" عن "قيد المراجعة" و"موقوف عن النشر" عن "قيد المراجعة"،
-- شيء ما كان ممكنًا بعمود is_published الثنائي وحده. is_published يبقى كما هو
-- (كل الاستعلامات القديمة تعمل بلا تعديل) ويتزامن معه العمود الجديد.

alter table public.restaurants
  add column if not exists status text not null default 'pending'
  check (status in ('pending', 'approved', 'rejected'));

update public.restaurants
  set status = case when is_published then 'approved' else 'pending' end
  where status = 'pending' and is_published = true;
