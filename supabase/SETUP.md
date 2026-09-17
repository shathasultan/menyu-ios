# تشغيل منيو بعد هجرة 0008 — خطوة خطوة

اتبعي الترتيب. كل خطوة تعتمد على التي قبلها.

---

## ٠) اسحبي الفرع وتأكدي من الأسرار

```bash
cd ~/Projects/menyu-ios        # أو أينما المستودع عندك
git fetch origin
git checkout fix/menyu-review-and-pricing
git pull
ls Menu/Secrets.swift
```

آخر أمر لازم يطبع المسار. إن قال «No such file»، انسخي القالب وعبّيه:

```bash
cp Secrets.swift.example Menu/Secrets.swift
```

ثم املئي `supabaseURL` و`supabaseKey` من Supabase ← Project Settings ← API
(`Project URL` و`anon public`). الملف مستثنى من Git عمدًا فلا يُرفع.

---

## ١) شغّلي الهجرة

Supabase ← **SQL Editor** ← **New query**.

الصقي كامل محتوى `supabase/migrations/0008_permissions_and_atomic_codes.sql`
واضغطي **Run**.

المتوقَّع: `Success. No rows returned`.

إن ظهر خطأ، انسخيه كما هو ولا تكملي — بقية الخطوات تفترض أن هذه نجحت.

> ملاحظة: إن ظهر إشعار `تعذّر إنشاء uq_...` فهذا ليس فشلًا للهجرة، بل يعني أن
> في بياناتك الحالية رمزين متكررين من السباق القديم. الاستعلامان في آخر ملف
> `verify_0008.sql` يعرضانهما.

---

## ٢) شغّلي الفحص واقرئي النتيجة

نفس المكان، **New query**، الصقي `supabase/verify_0008.sql` واضغطي Run.

يعطيك أربعة عشر سطرًا، كل واحد `PASS` أو `FAIL` مع السبب. اقرئيها كلها.

- الأسطر ١ إلى ٨ عن الهجرة نفسها. أي `FAIL` هنا يعني أن الخطوة ١ لم تكتمل.
- السطر ١٠ و١١ عن **حساب الأدمن التجريبي** — الخطوة ٣.
- السطر ١٢ عن **حسابك أنت**.
- السطر ١٤ عن تكرار الرموز القديم.

---

## ٣) أنشئي حساب الأدمن التجريبي

لا توجد هجرة تنشئ مستخدمًا — الهجرات تمنح الصلاحية لبريد، ولا تنشئ صاحبه.

Supabase ← **Authentication** ← **Users** ← **Add user** ← **Create new user**:

| الحقل | القيمة |
|---|---|
| Email | `demo.admin@menyu.sa` |
| Password | كلمة مرور جديدة (لا تستخدمي أي كلمة كُتبت في محادثة) |
| Auto Confirm User | **مفعَّل** |

«Auto Confirm» ضروري: بدونه يبقى البريد غير مؤكَّد، ويرفض الدخول بسبب مختلف
تمامًا عن كلمة المرور.

أعيدي تشغيل `verify_0008.sql` — لازم يصير السطران ١٠ و١١ `PASS`.

### وحسابك أنت
`shathasultann9@gmail.com` حساب قوقل، و**حسابات قوقل ليس لها كلمة مرور**. أمامك
خياران:

- **الأسهل:** ادخلي من زر «الدخول بحساب Google» في شاشة الأدمن.
- أو اضبطي له كلمة مرور من Authentication ← Users ← الحساب ← Reset password.

---

## ٤) اضبطي مزوّد قوقل في Supabase

Supabase ← **Authentication** ← **Providers** ← **Google**.

1. **Enable Sign in with Google**: مفعَّل.
2. **Authorized Client IDs**: أضيفي معرّف العميل الذي في
   `Menu/Info-Additions.plist` تحت `GIDClientID` — كاملًا، بنفس نصّه، وينتهي
   بـ`.apps.googleusercontent.com`.
3. اضغطي **Save**.

هذا الحقل تحديدًا هو ما يجعل Supabase يقبل الرمز القادم من تطبيق iOS. بدونه
يفتح المتصفح ويرجع ويفشل عند آخر خطوة.

> إن ضبطتِ كل ما سبق وبقي الرفض بشكوى عن `nonce`: في نفس الصفحة خيار
> **Skip nonce check**. مكتبة قوقل على iOS لا ترسل nonce، فقد يلزم تفعيله.
> جرّبيه فقط إن ظهر الخطأ فعلًا، لا استباقًا.

---

## ٥) تأكدي من معرّف العميل في Google Cloud

[console.cloud.google.com](https://console.cloud.google.com) ← المشروع الصحيح ←
**APIs & Services** ← **Credentials**.

ابحثي عن العميل الذي يطابق `GIDClientID`، وتأكدي:

- النوع **iOS** (ليس Web ولا Android).
- **Bundle ID** = `sa.bithrah.menu` — بالضبط، وهو ما في إعدادات المشروع.

إن لم يوجد عميل iOS: **Create Credentials** ← **OAuth client ID** ← **iOS** ←
أدخلي معرّف الحزمة. سيعطيك معرّفًا جديدًا، وحينها يلزم تحديث ثلاثة مواضع معًا:
`GIDClientID` في الـplist، ومخطط الرابط (نفس المعرّف معكوسًا)، وحقل
Authorized Client IDs في Supabase.

---

## ٦) ابني وشغّلي الاختبارات

في Xcode:

1. `⌘U` — تشغيل الاختبارات.
   - المتوقَّع أن ينجح كل شيء **عدا** `testGoogleOfficialMarkIsBundled`.
     هذا فشل مقصود: يذكّرك بإضافة شعار قوقل الأصلي قبل الرفع (الخطوة ٧).
   - إن فشل `testURLSchemeIsTheReversedClientID` أو
     `testGoogleClientIDIsPresentAndWellFormed`، فالمشكلة في الـplist لا في
     Supabase — راجعي الخطوة ٥.
2. `⌘R` — تشغيل التطبيق، ثم جرّبي بالترتيب:
   - أضيفي تصنيفًا ومنتجًا بسعر `14.50` — لازم يُحفظ `14.50` لا `14`.
   - اضغطي «حفظ بيانات المتجر» بعد كتابة جوال وعنوان، ثم أعيدي فتح التبويب.
   - بدّلي صورة منتج — لازم تتغير فورًا لا بعد ساعة.
   - ادخلي بحساب الأدمن التجريبي واعتمدي مطعمًا.

### إن فشل الدخول
شغّلي التطبيق من Xcode وافتحي **Console** أسفل النافذة، وابحثي عن سطر يبدأ بـ:

```
[menyu] sign-in failed — domain=... code=... — ...
```

هذا السطر يحمل السبب الحقيقي. أرسليه كما هو.

---

## ٧) قبل الرفع إلى App Store

- [ ] أضيفي شعار قوقل الأصلي من دليل علامتها إلى `Assets.xcassets` باسم
      `GoogleG`. شعار مقارب سبب رفض.
- [ ] تأكدي أن زر «الدخول بحساب أبل» يعمل فعلًا على جهاز حقيقي — إرشاد أبل 4.8
      يوجبه ما دام دخول قوقل معروضًا.
- [ ] راجعي أن الهدف iOS 17 يناسب أجهزتك المستهدفة.

---

## اختبار الباك اند محليًّا (اختياري)

يشغّل الهجرات كلها على PostgreSQL مؤقت وينفّذ ٢٩ فحص سلوك. لا يلمس Supabase.

```bash
brew install postgresql@16
PG_BIN=$(brew --prefix postgresql@16)/bin bash supabase/tests/run.sh
```
