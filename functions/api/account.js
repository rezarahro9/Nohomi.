
const output=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'}});
export async function onRequestPost({request,env}){
  if(!env.SUPABASE_URL||!env.SUPABASE_ANON_KEY||!env.SUPABASE_SERVICE_ROLE_KEY)return output({error:'تنظیمات سرویس حساب‌ها کامل نیست'},503);
  try{
    if(Number(request.headers.get('content-length')||0)>4096)return output({error:'درخواست بزرگ است'},413);
    const {action,username,password}=await request.json();
    if(!['signup','login'].includes(action)||typeof username!=='string'||typeof password!=='string'||!/^[a-z][a-z0-9_]{2,24}$/.test(username)||password.length<8||password.length>128)return output({error:'نام کاربری یا رمز نامعتبر است'},400);
    // Pseudonymous internal account, provisioned with admin API so no email confirmation is sent.
    const email=username+'@accounts.nahomino.example';
    const base=env.SUPABASE_URL.replace(/\/$/,'');
    let r,data;
    if(action==='signup'){
      r=await fetch(base+'/auth/v1/admin/users',{method:'POST',headers:{apikey:env.SUPABASE_SERVICE_ROLE_KEY,authorization:'Bearer '+env.SUPABASE_SERVICE_ROLE_KEY,'content-type':'application/json'},body:JSON.stringify({email,password,email_confirm:true,user_metadata:{display_name:username,username}})});
      data=await r.json();
    }else{
      r=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:env.SUPABASE_ANON_KEY,'content-type':'application/json'},body:JSON.stringify({email,password})});
      data=await r.json();
    }
    if(!r.ok)return output({error:action==='login'?'نام کاربری یا رمز اشتباه است':'ساخت حساب ممکن نشد؛ شاید نام کاربری گرفته شده باشد یا محدودیت ثبت‌نام فعال باشد'},r.status===429?429:400);
    if(action==='signup')return output({ok:true,needs_login:true});
    return output({access_token:data.access_token,expires_in:data.expires_in,token_type:'bearer'});
  }catch{return output({error:'درخواست قابل پردازش نبود'},400)}
}
