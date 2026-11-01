const json=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'}});
export async function onRequestPost({request,env}){
 try{
  if(!env.SUPABASE_URL||!env.SUPABASE_SERVICE_ROLE_KEY||!env.SUPABASE_ANON_KEY||!env.GEMINI_API_KEY)return json({error:'تنظیمات سرویس هنوز کامل نیست'},503);
  const bearer=request.headers.get('authorization')||'';if(!bearer.startsWith('Bearer '))return json({error:'ابتدا وارد شوید'},401);
  const token=bearer.slice(7);
  const userResponse=await fetch(`${env.SUPABASE_URL}/auth/v1/user`,{headers:{apikey:env.SUPABASE_ANON_KEY,authorization:`Bearer ${token}`}});
  if(!userResponse.ok)return json({error:'نشست کاربری نامعتبر است'},401);
  const user=await userResponse.json();if(!user.id)return json({error:'شناسه کاربری نامعتبر'},401);
  const auth={apikey:env.SUPABASE_SERVICE_ROLE_KEY,authorization:`Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`};
  const profResponse=await fetch(`${env.SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=role`,{headers:auth});
  if(!profResponse.ok)return json({error:'عدم دسترسی به نقش‌ها'},503);
  const profiles=await profResponse.json();const role=profiles[0]?.role;
  if(!['teacher','admin'].includes(role))return json({error:'تولید عمومی AI فقط برای معلم و مدیر مجاز است'},403);
  const payload=await request.json();const {mode,subject,topic,source='',count=5}=payload;
  if(!['lesson','exam'].includes(mode)||typeof subject!=='string'||typeof topic!=='string'||typeof source!=='string'||!subject.trim()||!topic.trim()||source.length>14000||topic.length>300||Number(count)>15||Number(count)<1)return json({error:'درخواست نامعتبر است'},400);
  const quota=await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/bump_ai_usage`,{method:'POST',headers:{...auth,'content-type':'application/json'},body:JSON.stringify({p_user:user.id,p_daily_limit:10})});
  if(!quota.ok)return json({error:'سهمیه روزانه در دسترس نیست'},503);
  if((await quota.json())!==true)return json({error:'سهمیه رایگان امروز (۱۰ درخواست) تکمیل شد'},429);
  const prompt=mode==='lesson'
   ?`به فارسی و مناسب پایه نهم، فقط با تکیه بر متن منبع زیر یک جزوه آموزشی بنویس. در صورت نبود منبع کافی ادعای قطعیت نکن. محتوای کتابی را عیناً بازنویسی طولانی نکن. درس: ${subject}\nمبحث: ${topic}\nمنبع معلم:\n${source||'منبع ارائه نشده؛ متن پیشنهادی عمومی است و نیاز به تأیید معلم دارد.'}\nفقط متن ساده خوانا برگردان.`
   :`برای دانش‌آموز پایه نهم یک امتحان جدید ۴ گزینه‌ای در درس ${subject} و مبحث ${topic} با ${Math.floor(count)} سوال طراحی کن. فقط از اطلاعات صحیح و متناسب با منبع استفاده کن. منبع:\n${source||'منبع ارائه نشده؛ نیازمند تأیید معلم'}\nخروجی فقط JSON معتبر و بدون markdown با این قالب باشد: {"questions":[{"text":"...","options":["...","...","...","..."],"answer":0}]}. answer اندیس پاسخ درست بین 0 تا 3 باشد.`;
  const model=env.GEMINI_MODEL||'gemini-2.5-flash';
  const result=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,{method:'POST',headers:{'x-goog-api-key':env.GEMINI_API_KEY,'content-type':'application/json'},body:JSON.stringify({contents:[{parts:[{text:prompt}]}],generationConfig:{temperature:0.4,maxOutputTokens:5000,...(mode==='exam'?{responseMimeType:'application/json'}:{})}})});
  if(!result.ok){const err=await result.text();return json({error:'مدل در دسترس نیست یا سهمیه آن تکمیل شده است',detail:err.slice(0,180)},502)}
  const resultJson=await result.json();const output=(resultJson.candidates?.[0]?.content?.parts||[]).map(x=>x.text||'').join('');
  if(!output)return json({error:'مدل پاسخی برنگرداند'},502);
  if(mode==='lesson')return json({text:output});
  let parsed;try{parsed=JSON.parse(output.replace(/^```(?:json)?\s*|\s*```$/g,''));}catch{return json({error:'قالب پاسخ مدل قابل خواندن نبود'},502)}
  const questions=parsed.questions;if(!Array.isArray(questions)||questions.length>15||!questions.length||!questions.every(q=>typeof q.text==='string'&&Array.isArray(q.options)&&q.options.length===4&&q.options.every(o=>typeof o==='string')&&Number.isInteger(q.answer)&&q.answer>=0&&q.answer<=3))return json({error:'سؤال‌های تولیدشده ساختار صحیح ندارند'},502);
  return json({questions});
 }catch(e){return json({error:'خطا در پردازش درخواست'} ,500)}
}
