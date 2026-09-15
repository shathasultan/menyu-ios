-- منيو — حجز الحرف والرقم ذرّيًا
--
-- المشكلة: addCategory و addItem في AppStore كانا يقرآن العدّاد بطلب، ثم
-- يكتبان العدّاد+1 بطلب ثانٍ. إضافتان متزامنتان (جهازان، أو نقرتان سريعتان)
-- تقرآن نفس القيمة قبل أن تكتبها أيّ منهما، فيخرج تصنيفان بحرف واحد، أو
-- منتجان برمز واحد — والرمز هو ما يبحث به الزبون، فالبحث يطلّع منتجًا غلط.
--
-- الحل: UPDATE ... RETURNING واحد. القفل على الصف يسلسل الطلبات المتزامنة،
-- فكل نداء يحجز قيمة تخصّه وحده.
--
-- security invoker (الافتراضي): سياسات RLS القائمة هي التي تقرّر من يملك
-- التعديل. غير المالك لا يحدّث شيئًا، فيرجع NULL ونرفع الخطأ.
--
-- ملاحظة: لو فشل الإدراج بعد الحجز تبقى فجوة في الترقيم. فجوة أهون من تكرار.

create or replace function public.claim_category_index(p_restaurant_id uuid)
returns table (claimed_index integer)
language plpgsql
set search_path = ''
as $$
declare
  v_index integer;
begin
  update public.restaurants
     set next_category_index = next_category_index + 1
   where id = p_restaurant_id
  returning next_category_index - 1 into v_index;

  if v_index is null then
    raise exception 'لا يمكن إضافة تصنيف لهذا المطعم' using errcode = '42501';
  end if;

  return query select v_index;
end;
$$;

grant execute on function public.claim_category_index(uuid) to authenticated;

-- أسماء أعمدة الخرج مختلفة عن أعمدة الجدول عمدًا: لو سمّينا عمود الخرج
-- letter لصار مرجع letter داخل RETURNING ملتبسًا بينه وبين عمود الجدول.
create or replace function public.claim_item_number(p_category_id uuid)
returns table (claimed_letter text, claimed_number integer)
language plpgsql
set search_path = ''
as $$
declare
  v_letter text;
  v_number integer;
begin
  update public.menu_categories
     set next_item_number = next_item_number + 1
   where id = p_category_id
  returning letter, next_item_number - 1
       into v_letter, v_number;

  if v_letter is null then
    raise exception 'لا يمكن إضافة منتج لهذا التصنيف' using errcode = '42501';
  end if;

  return query select v_letter, v_number;
end;
$$;

grant execute on function public.claim_item_number(uuid) to authenticated;
