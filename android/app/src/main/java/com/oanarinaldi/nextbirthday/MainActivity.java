package com.oanarinaldi.nextbirthday;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.*;
import android.provider.ContactsContract;
import android.view.*;
import android.webkit.*;
import android.widget.FrameLayout;
import androidx.activity.ComponentActivity;
import androidx.activity.OnBackPressedCallback;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.core.content.FileProvider;
import androidx.webkit.WebViewAssetLoader;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.*;
import org.json.*;

public final class MainActivity extends ComponentActivity {
  private WebView web;
  private BirthdayStore store;
  private Entitlements entitlement;
  private PlayBilling billing;
  private boolean ready;
  private String deepLink;
  private ActivityResultLauncher<String[]> importer;
  private ActivityResultLauncher<String> contactsPermission,notifications;
  private ActivityResultLauncher<androidx.activity.result.PickVisualMediaRequest> photoPicker;
  static final String ORIGIN="https://appassets.androidplatform.net";

  @Override public void onCreate(Bundle saved) {
    super.onCreate(saved);
    store=new BirthdayStore(this);entitlement=new Entitlements(this);
    importer=registerForActivityResult(new ActivityResultContracts.OpenDocument(),uri->{if(uri!=null)readImport(uri);});
    contactsPermission=registerForActivityResult(new ActivityResultContracts.RequestPermission(),ok->{if(ok)loadContacts();else js("window.receiveContacts?.(null)");});
    notifications=registerForActivityResult(new ActivityResultContracts.RequestPermission(),ok->js("window.notificationPermission?.("+ok+")"));
    photoPicker=registerForActivityResult(new ActivityResultContracts.PickVisualMedia(),uri->{if(uri!=null)readPhoto(uri);});
    web=new WebView(this);web.setBackgroundColor(0xfff6f3ea);web.setVerticalScrollBarEnabled(false);web.setHorizontalScrollBarEnabled(false);
    web.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS);
    WebSettings settings=web.getSettings();settings.setJavaScriptEnabled(true);settings.setDomStorageEnabled(false);settings.setAllowFileAccess(false);settings.setAllowContentAccess(false);settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
    WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
    WebViewAssetLoader loader=new WebViewAssetLoader.Builder().addPathHandler("/assets/",new WebViewAssetLoader.AssetsPathHandler(this)).build();
    web.setWebViewClient(new WebViewClient(){
      @Override public WebResourceResponse shouldInterceptRequest(WebView v,WebResourceRequest r){
        WebResourceResponse response=loader.shouldInterceptRequest(r.getUrl());
        return response!=null?response:new WebResourceResponse("text/plain","UTF-8",403,"Forbidden",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));
      }
      @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){if(r.isForMainFrame())open(r.getUrl().toString());return true;}
      @Override public void onPageFinished(WebView v,String url){ready=true;billingChanged();handleLink();}
    });
    web.setWebChromeClient(new WebChromeClient(){@Override public boolean onConsoleMessage(ConsoleMessage m){if(BuildConfig.DEBUG)android.util.Log.d("NextBirthdayWeb",m.message()+" @ "+m.lineNumber());return true;}});
    web.addJavascriptInterface(new Bridge(),"Android");
    FrameLayout root=new FrameLayout(this);root.setBackgroundColor(0xfff6f3ea);root.addView(web,new FrameLayout.LayoutParams(-1,-1));setContentView(root);
    root.setOnApplyWindowInsetsListener((v,i)->{android.graphics.Insets bars=i.getInsets(WindowInsets.Type.systemBars()),ime=i.getInsets(WindowInsets.Type.ime());v.setPadding(bars.left,bars.top,bars.right,Math.max(bars.bottom,ime.bottom));return WindowInsets.CONSUMED;});
    getWindow().getInsetsController().setSystemBarsAppearance(WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS|WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS|WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS);
    getOnBackPressedDispatcher().addCallback(this,new OnBackPressedCallback(true){@Override public void handleOnBackPressed(){js("window.goBack?.()");}});
    billing=new PlayBilling(this,entitlement,this::billingChanged,this::message);
    deepLink=getIntent().getDataString();
    web.loadUrl(ORIGIN+"/assets/index.html");billing.start();ReminderReceiver.schedule(this);BirthdayWidget.updateAll(this);
  }
  @Override protected void onResume(){super.onResume();if(billing!=null)billing.refresh(false);if(ready)js("window.refreshData?.()");BirthdayWidget.updateAll(this);ReminderReceiver.schedule(this);}
  @Override protected void onNewIntent(Intent i){super.onNewIntent(i);setIntent(i);deepLink=i.getDataString();handleLink();}
  private void handleLink(){if(ready&&deepLink!=null){js("window.openDeepLink?.("+JSONObject.quote(deepLink)+")");deepLink=null;}}
  @Override protected void onDestroy(){if(billing!=null)billing.close();web.removeJavascriptInterface("Android");web.destroy();super.onDestroy();}
  void js(String code){runOnUiThread(()->{if(!isDestroyed())web.evaluateJavascript(code,null);});}
  void message(String text){js("window.showMessage?.("+JSONObject.quote(text)+")");}
  void open(String raw){
    Uri u=Uri.parse(raw);String scheme=u.getScheme();if(!List.of("https","mailto","tel","smsto","sms").contains(scheme==null?"":scheme))return;
    runOnUiThread(()->{try {startActivity(new Intent("tel".equals(scheme)?Intent.ACTION_DIAL:Intent.ACTION_VIEW,u));}catch(ActivityNotFoundException e){message("No app is available to open this link.");}});
  }
  void billingChanged(){
    if(!ready||billing==null)return;
    try{
      JSONObject b=new JSONObject().put("isPro",entitlement.isPro()).put("loading",billing.loading).put("busy",billing.busy);JSONArray plans=new JSONArray();
      for(String id:List.of(PlayBilling.PREFIX+"monthly",PlayBilling.PREFIX+"yearly")){
        PlayBilling.Plan p=billing.plans.get(id);if(p!=null)plans.put(new JSONObject().put("id",p.id()).put("title",p.title()).put("price",p.price()).put("note",p.note()).put("trial",p.trial()));
      }
      b.put("plans",plans);js("window.onBilling?.("+b+")");
    }catch(JSONException e){message("Could not load plans. Please try again.");}
  }
  void readImport(Uri uri){new Thread(()->{try(InputStream in=getContentResolver().openInputStream(uri)){if(in==null)throw new IOException();byte[] bytes=readLimited(in,32*1024*1024);js("window.receiveImport?.("+JSONObject.quote(new String(bytes,StandardCharsets.UTF_8))+")");}catch(IOException e){message("Choose a Next Birthday JSON backup smaller than 32 MB.");}},"BirthdayImport").start();}
  static byte[] readLimited(InputStream in,int max)throws IOException{ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buffer=new byte[8192];int n;while((n=in.read(buffer))!=-1){if(out.size()+n>max)throw new IOException("Too large");out.write(buffer,0,n);}return out.toByteArray();}
  void readPhoto(Uri uri){new Thread(()->{try(InputStream in=getContentResolver().openInputStream(uri)){
    if(in==null)throw new IOException();byte[] raw=readLimited(in,24*1024*1024);BitmapFactory.Options opts=new BitmapFactory.Options();opts.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(raw,0,raw.length,opts);opts.inSampleSize=1;while(Math.max(opts.outWidth,opts.outHeight)/opts.inSampleSize>1200)opts.inSampleSize*=2;opts.inJustDecodeBounds=false;
    Bitmap src=BitmapFactory.decodeByteArray(raw,0,raw.length,opts);if(src==null)throw new IOException();float factor=Math.min(1f,600f/Math.max(src.getWidth(),src.getHeight()));Bitmap dst=Bitmap.createScaledBitmap(src,Math.max(1,Math.round(src.getWidth()*factor)),Math.max(1,Math.round(src.getHeight()*factor)),true);ByteArrayOutputStream out=new ByteArrayOutputStream();dst.compress(Bitmap.CompressFormat.JPEG,85,out);String data="data:image/jpeg;base64,"+android.util.Base64.encodeToString(out.toByteArray(),android.util.Base64.NO_WRAP);js("window.receivePhoto?.("+JSONObject.quote(data)+")");if(dst!=src)dst.recycle();src.recycle();
    }catch(IOException|RuntimeException e){message("Could not load that photo. Choose a smaller image.");}},"BirthdayPhoto").start();}
  void loadContacts(){new Thread(()->{
    JSONArray result=new JSONArray();String mime=ContactsContract.CommonDataKinds.Event.CONTENT_ITEM_TYPE;
    try(Cursor c=getContentResolver().query(ContactsContract.Data.CONTENT_URI,new String[]{ContactsContract.Data.CONTACT_ID,ContactsContract.Data.DISPLAY_NAME,ContactsContract.CommonDataKinds.Event.START_DATE},ContactsContract.Data.MIMETYPE+"=? AND "+ContactsContract.CommonDataKinds.Event.TYPE+"=?",new String[]{mime,String.valueOf(ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY)},ContactsContract.Data.DISPLAY_NAME+" COLLATE NOCASE")){
      Set<String> seen=new HashSet<>();
      while(c!=null&&c.moveToNext()){
        String id=c.getString(0),display=c.getString(1),raw=c.getString(2);if(!seen.add(id)||raw==null)continue;
        try{
          String date=raw.startsWith("--")?"2000"+raw.substring(1):raw;LocalDate d=LocalDate.parse(date);
          String first=display==null?"":display.trim(),last="";int space=first.indexOf(' ');if(space>=0){last=first.substring(space+1);first=first.substring(0,space);}
          JSONObject p=new JSONObject().put("contactIdentifier",id).put("firstName",first).put("lastName",last).put("birthMonth",d.getMonthValue()).put("birthDay",d.getDayOfMonth()).put("birthYear",raw.startsWith("--")?JSONObject.NULL:d.getYear());
          try(Cursor names=getContentResolver().query(ContactsContract.Data.CONTENT_URI,new String[]{ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME,ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME},ContactsContract.Data.CONTACT_ID+"=? AND "+ContactsContract.Data.MIMETYPE+"=?",new String[]{id,ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE},null)){if(names!=null&&names.moveToFirst()){p.put("firstName",names.getString(0)==null?first:names.getString(0));p.put("lastName",names.getString(1)==null?"":names.getString(1));}}
          p.put("phone",contactValue(id,ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE,ContactsContract.CommonDataKinds.Phone.NUMBER));p.put("email",contactValue(id,ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE,ContactsContract.CommonDataKinds.Email.ADDRESS));result.put(p);
        }catch(Exception ignored){/* A contact with an unsupported date format is skipped. */}
      }
      js("window.receiveContacts?.("+result+")");
    }catch(SecurityException e){js("window.receiveContacts?.(null)");}
  },"BirthdayContacts").start();}
  private String contactValue(String id,String mime,String field){try(Cursor c=getContentResolver().query(ContactsContract.Data.CONTENT_URI,new String[]{field},ContactsContract.Data.CONTACT_ID+"=? AND "+ContactsContract.Data.MIMETYPE+"=?",new String[]{id,mime},null)){return c!=null&&c.moveToFirst()?c.getString(0):"";}}

  public final class Bridge {
    @JavascriptInterface public String read(){try{return store.read();}catch(IllegalStateException e){return "{unreadable";}}
    @JavascriptInterface public boolean save(String raw,int revision){boolean ok=store.save(raw,revision);if(ok){ReminderReceiver.schedule(MainActivity.this);BirthdayWidget.updateAll(MainActivity.this);}return ok;}
    @JavascriptInterface public boolean isPro(){return entitlement.isPro();}
    @JavascriptInterface public void plans(){runOnUiThread(()->billing.start());}
    @JavascriptInterface public void buy(String id){runOnUiThread(()->billing.buy(id));}
    @JavascriptInterface public void restore(){runOnUiThread(()->billing.refresh(true));}
    @JavascriptInterface public void open(String url){MainActivity.this.open(url);}
    @JavascriptInterface public void quit(){runOnUiThread(()->moveTaskToBack(true));}
    @JavascriptInterface public void importBackup(){runOnUiThread(()->importer.launch(new String[]{"application/json","text/plain"}));}
    @JavascriptInterface public void requestNotifications(){runOnUiThread(()->{if(Build.VERSION.SDK_INT>=33)notifications.launch(Manifest.permission.POST_NOTIFICATIONS);else js("window.notificationPermission?.(true)");});}
    @JavascriptInterface public boolean notificationsAllowed(){return Build.VERSION.SDK_INT<33||checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED;}
    @JavascriptInterface public void notificationSettings(){runOnUiThread(()->startActivity(new Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(android.provider.Settings.EXTRA_APP_PACKAGE,getPackageName())));}
    @JavascriptInterface public void contacts(){runOnUiThread(()->{if(checkSelfPermission(Manifest.permission.READ_CONTACTS)==PackageManager.PERMISSION_GRANTED)loadContacts();else contactsPermission.launch(Manifest.permission.READ_CONTACTS);});}
    @JavascriptInterface public void photo(){runOnUiThread(()->photoPicker.launch(new androidx.activity.result.PickVisualMediaRequest.Builder().setMediaType(ActivityResultContracts.PickVisualMedia.ImageOnly.INSTANCE).build()));}
    @JavascriptInterface public void copy(String text){runOnUiThread(()->((ClipboardManager)getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("Birthday message",text)));}
    @JavascriptInterface public void shareText(String text){runOnUiThread(()->startActivity(Intent.createChooser(new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,text),"Share Birthday")));}
    @JavascriptInterface public void export(String json){if(json.length()>32*1024*1024)return;runOnUiThread(()->{
      try{File dir=new File(getCacheDir(),"exports");if(!dir.exists()&&!dir.mkdirs())throw new IOException();File f=new File(dir,"NextBirthday-"+LocalDate.now()+".json");try(OutputStream out=new FileOutputStream(f)){out.write(json.getBytes(StandardCharsets.UTF_8));}Uri uri=FileProvider.getUriForFile(MainActivity.this,getPackageName()+".files",f);startActivity(Intent.createChooser(new Intent(Intent.ACTION_SEND).setType("application/json").putExtra(Intent.EXTRA_STREAM,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),"Export Next Birthday"));}catch(IOException|ActivityNotFoundException e){message("Could not export. Please try again.");}
    });}
    @JavascriptInterface public boolean reviewAccess(String code){if(BuildConfig.REVIEW_CODE_SHA256.isEmpty())return false;try{byte[] bytes=java.security.MessageDigest.getInstance("SHA-256").digest(code.getBytes(StandardCharsets.UTF_8));StringBuilder hex=new StringBuilder();for(byte b:bytes)hex.append(String.format(Locale.ROOT,"%02x",b));if(!java.security.MessageDigest.isEqual(hex.toString().getBytes(StandardCharsets.US_ASCII),BuildConfig.REVIEW_CODE_SHA256.getBytes(StandardCharsets.US_ASCII)))return false;entitlement.reviewAccess();runOnUiThread(MainActivity.this::billingChanged);return true;}catch(java.security.NoSuchAlgorithmException e){return false;}}
  }
}
