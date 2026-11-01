# نهمینو — سایت آموزشی پایه نهم با زیرساخت رایگان

این پروژه **نمونه عملیاتی اولیه (MVP)** است؛ برخلاف نسخه‌های صرفاً HTML، داده‌ها در Supabase نگهداری می‌شوند و API هوش مصنوعی از Cloudflare Pages Functions اجرا می‌شود. **هنوز استقرار و اتصال واقعی انجام نشده‌اند** و بدون حساب‌ها، کلیدها و تنظیمات شما کار آنلاین نخواهد کرد.

## امکانات موجود

- ۱۰ درس، سه بخش پیش‌فرض، مطالب شماره‌دار، صفحه مطلب، ناوبری قبلی/بعدی و لینک‌های قابل کلیک
- ثبت‌نام/ورود از طریق Supabase Auth؛ نقش دانش‌آموز، معلم، مدیر
- انتشار مطالب و پیوست‌های ۲۰ مگابایتی؛ تصویر، ویدئو، PDF داخل صفحه و فایل‌های متنی/Word/PowerPoint به شکل لینک
- ساخت دستی امتحان چهارگزینه‌ای یا تولید امتحان با Gemini؛ پاسخنامه جدا و غیرقابل‌خواندن برای دانش‌آموز
- تصحیح تستی در PostgreSQL، جلوگیری از ارسال دوبارهٔ همان آزمون، کارنامه روزانه/۷روز اخیر/ماهانه
- نظارت مدیر بر سوالات، کلید آزمون‌ها و وضعیت انتشار؛ ۱۰ درخواست AI در روز برای هر مدیر/معلم
- تولید جزوه با Gemini از متن منبع، ذخیره به‌صورت پیش‌نویس

## مراحل شروع (به ترتیب)

1. در [Supabase](https://supabase.com/dashboard) حساب رایگان باز کنید و یک پروژه بسازید. از **Project Settings → API** آدرس Project URL و کلید **publishable یا anon** را بردارید. **service_role** کلید محرمانه است.
2. SQL Editor را باز کنید، تمام محتویات `schema.sql` را اجرا کنید.
3. `assets/config.js` را ویرایش کنید و `SUPABASE_URL` و `SUPABASE_ANON_KEY` را با مقادیر **عمومی** پروژه پر کنید. *هرگز `service_role` یا کلید Gemini را در این فایل نگذارید.*
4. این پروژه را در یک مخزن **خصوصی GitHub** قرار دهید. سپس در [Cloudflare](https://dash.cloudflare.com/) → Workers & Pages → Create → Pages → Connect to Git، مخزن را انتخاب کنید. **Build command** خالی و **output directory** برابر `.` باشد. برای Pages Functions، **آپلود مستقیم ZIP از داشبورد پشتیبانی نمی‌شود**؛ باید اتصال Git یا Wrangler داشته باشید.
5. در Cloudflare Pages → Settings → Variables and Secrets متغیرهای زیر را تعریف کنید (Production و در صورت نیاز Preview):
   - `SUPABASE_URL`: Project URL
   - `SUPABASE_ANON_KEY`: کلید عمومی پروژه
   - `SUPABASE_SERVICE_ROLE_KEY`: کلید محرمانه Supabase، **Encrypt**
   - `GEMINI_API_KEY`: کلید Gemini از [Google AI Studio](https://aistudio.google.com/apikey)، **Encrypt**
   - `GEMINI_MODEL` (اختیاری): `gemini-2.5-flash`؛ بسته به دسترسی و سهمیه رایگان حساب تنظیم شود
6. Deploy کنید. آدرس رایگان `project.pages.dev` اختصاص داده می‌شود. به Supabase → Authentication → URL Configuration بروید و **Site URL** و Redirect URLs را با آدرس Cloudflare هماهنگ کنید. برای ثبت‌نام ایمیلی، تنظیمات **Confirm email** را هم بررسی کنید.
7. در سایت ثبت‌نام کنید. سپس به Supabase SQL Editor بروید و **فقط برای ایمیل واقعی خودتان** فرمان زیر را اجرا کنید:

```sql
update public.profiles set role='admin'
where id=(select id from auth.users where email='YOUR_ADMIN_EMAIL');
```

برای حساب واقعی معلم نیز پس از ثبت‌نام آن شخص:

```sql
update public.profiles set role='teacher'
where id=(select id from auth.users where email='TEACHER_EMAIL');
```

هر کاربر جدید نقش `student` دارد؛ **با رمز ثابت یا مشترک نقش‌دهی نکنید**. رمزهای قدیمی که در چت گفته شده‌اند را برای سایت عمومی تکرار نکنید.

8. سایت را آزمایش کنید: حساب مدیر، معلم و دانش‌آموز؛ ایجاد مطلب/فایل؛ آزمون پیش‌نویس؛ انتشار مدیر؛ شرکت دانش‌آموز؛ ثبت کارنامه؛ تولید AI.
9. برای پیدا شدن در جست‌وجو، سایت را در [Google Search Console](https://search.google.com/search-console) ثبت کنید. `robots.txt` موجود است؛ برای سئوی واقعی بهتر باید در نسخه بعدی صفحات عمومی هر درس و هر مطلب را با URL مستقل و قابل رندر در سرور پیاده‌سازی کنیم.

## اجرای محلی

نیاز به Node.js دارید. در پوشه پروژه `npm install` سپس `npm run dev` را اجرا کنید. فایل **`.dev.vars`** محلی را از روی اسامی متغیرهای مرحله ۵ بسازید؛ داخل Git قرار ندهید. قابلیت‌های ورود/آزمون نیازمند Supabase تنظیم‌شده هستند. در حالت بدون اتصال می‌توان ظاهر سایت را دید.

## مهم: مرزهای نسخه اولیه

- **سرویس رایگان نامحدود نیست.** محدودیت‌های Supabase، Cloudflare، Google AI Studio و منطقهٔ ارائهٔ سرویس ممکن است تغییر کند. بدون کلید Gemini ساخت AI واقعی فعال نمی‌شود.
- پیش از پذیرش دانش‌آموزان واقعی و به‌ویژه افراد زیر ۱۸ سال: رضایت سرپرست در صورت نیاز، سیاست حریم خصوصی، حفاظت داده، حذف داده و فرآیند پشتیبان‌گیری را آماده کنید. در پلن رایگان Gemini ممکن است داده‌ها طبق شرایط سرویس برای بهبود محصولات پردازش شوند. اطلاعات شخصی دانش‌آموزان را برای AI نفرستید.
- **تصحیح تشریحی، تولید از فایل PDF آپلودشده، ساخت PDF آماده چاپ، زمان‌بندی خودکار به‌روزرسانی منابع، گزارش کلاسی، SEO کامل URLهای مطالب و ورود دانش‌آموز با کد کلاسی هنوز اجرا نشده‌اند.** فعلاً ورودی AI متن منبع است و تصحیح خودکار فقط ۴ گزینه‌ای است.
- کلیدهای API محرمانه فقط در Cloudflare Secrets ذخیره شوند. بانک اطلاعاتی و ذخیره‌سازی با RLS حفاظت می‌شوند، اما پیش از استفاده عمومی نیازمند تست امنیت، بار و حریم خصوصی هستند.
- فایل‌های تدریس در bucket عمومی هستند؛ **فایل خصوصی، پاسخ دانش‌آموز و اطلاعات محرمانه در آن بارگذاری نکنید**.
- برای حذف/ویرایش مطالب و کنترل کامل مدیر، مرحله بعدی بهتر است رابط ویرایش و پنل مدیریت کاربران ساخته شود؛ سیاست‌های سطح دیتابیس آماده‌اند.
- اتصال به ChatGPT اشتراک شخصی نیست؛ API آن هزینه/سهمیه جداگانه دارد. در این نسخه از Gemini free tier استفاده شده است.

## لینک‌های مستندات

- [Cloudflare Pages Functions](https://developers.cloudflare.com/pages/functions/get-started/)
- [Cloudflare Secrets](https://developers.cloudflare.com/pages/functions/bindings/)
- [Supabase security and RLS](https://supabase.com/docs/guides/database/secure-data)
- [Gemini API](https://ai.google.dev/api)
