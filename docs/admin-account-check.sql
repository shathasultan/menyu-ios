-- منيو — فحص حساب الإدارة
--
-- شغّلي هذا في: Supabase Dashboard → SQL Editor → New query
--
-- يجيب حسابات auth.users ويقول عن كل واحد: هل له كلمة مرور، هل بريده
-- مؤكَّد، هل بنيته سليمة، وهل بريده مطابق لقائمة الإدارة في
-- AppStore.swift وسياسات الترحيل 0008.
--
-- قراءة النتيجة:
--   ✗ بلا كلمة مرور  → الحساب أُنشئ بقوقل أو بـINSERT ناقص. دخول
--                      الإدارة يطلب بريدًا وكلمة مرور، فلن يعمل معه أبدًا.
--   ✗ غير مؤكَّد      → GoTrue يرفض الدخول. أنشئيه من اللوحة مع تفعيل
--                      Auto Confirm User، أو عيّني email_confirmed_at.
--   ✗ ناقص           → صفٌّ أُدخل بـSQL يدويًا بلا instance_id/aud/role.
--                      الأسلم حذفه وإنشاؤه من Authentication → Add user.
--   ✗ غير مطابق      → الدخول ينجح لكن التطبيق يخرجك فورًا برسالة
--                      «هذا البريد لا يملك صلاحية الإدارة»، لأن البريد
--                      مكتوب حرفيًا في ثلاثة مواضع ولا بد أن يتطابق.

select
  email,
  case when encrypted_password is null or encrypted_password = ''
       then '✗ بلا كلمة مرور' else '✓ له كلمة مرور' end            as "كلمة المرور",
  case when email_confirmed_at is null
       then '✗ غير مؤكَّد'   else '✓ مؤكَّد'      end               as "تأكيد البريد",
  case when aud = 'authenticated' and role = 'authenticated'
            and instance_id is not null
       then '✓ سليم'        else '✗ ناقص'        end               as "بنية الحساب",
  coalesce(raw_app_meta_data ->> 'provider', '—')                   as "المزوّد",
  case when banned_until > now() then '✗ محظور'
       when deleted_at is not null then '✗ محذوف'
       else '✓ نشط' end                                            as "الحالة",
  case when email = 'demo.admin@menyu.sa' then '✓ مطابق'
       else '✗ غير مطابق لقائمة الأدمن' end                         as "بريد الإدارة"
from auth.users
order by email;
