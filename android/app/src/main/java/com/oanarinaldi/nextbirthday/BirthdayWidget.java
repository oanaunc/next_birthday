package com.oanarinaldi.nextbirthday;

import android.app.*;
import android.appwidget.*;
import android.content.*;
import android.graphics.*;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.Gravity;
import android.widget.RemoteViews;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import org.json.*;

/** Resizable Up Next, Countdown, and compact widgets using the iOS palette and deep links. */
public class BirthdayWidget extends AppWidgetProvider {
  @Override public void onUpdate(Context c,AppWidgetManager manager,int[] ids){for(int id:ids)update(c,manager,id);ReminderReceiver.schedule(c);}
  @Override public void onAppWidgetOptionsChanged(Context c,AppWidgetManager manager,int id,Bundle options){update(c,manager,id);}
  @Override public void onDeleted(Context c,int[] ids){for(int id:ids)c.getSharedPreferences("widgets",Context.MODE_PRIVATE).edit().remove("person-"+id).apply();}
  static PendingIntent link(Context c,String id,int request){return PendingIntent.getActivity(c,request,new Intent(c,MainActivity.class).setData(Uri.parse(id.isEmpty()?"nextbirthday://add":"nextbirthday://person/"+id)).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);}
  static void updateAll(Context c){AppWidgetManager manager=AppWidgetManager.getInstance(c);for(Class<?> type:List.of(BirthdayWidget.class,CountdownWidget.class,CompactWidget.class))for(int id:manager.getAppWidgetIds(new ComponentName(c,type)))update(c,manager,id);}
  static Bitmap avatar(JSONObject person){
    Bitmap bitmap=Bitmap.createBitmap(96,96,Bitmap.Config.ARGB_8888);Canvas canvas=new Canvas(bitmap);Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);paint.setShader(new LinearGradient(0,0,96,96,0xffb7ccb2,0xff245c49,Shader.TileMode.CLAMP));canvas.drawCircle(48,48,48,paint);
    String photo=person.optString("photoData");if(photo.startsWith("data:image/"))try{byte[] data=android.util.Base64.decode(photo.substring(photo.indexOf(',')+1),android.util.Base64.DEFAULT);Bitmap src=BitmapFactory.decodeByteArray(data,0,data.length);if(src!=null){BitmapShader shader=new BitmapShader(Bitmap.createScaledBitmap(src,96,96,true),Shader.TileMode.CLAMP,Shader.TileMode.CLAMP);paint.setShader(shader);canvas.drawCircle(48,48,48,paint);src.recycle();return bitmap;}}catch(IllegalArgumentException ignored){}
    paint.setShader(null);paint.setColor(Color.WHITE);paint.setTextSize(34);paint.setTypeface(Typeface.create("sans-serif",Typeface.BOLD));paint.setTextAlign(Paint.Align.CENTER);String first=person.optString("firstName"),last=person.optString("lastName");String initials=(first.isEmpty()?"":first.substring(0,1))+(last.isEmpty()?"":last.substring(0,1));canvas.drawText(initials.toUpperCase(Locale.getDefault()),48,60,paint);return bitmap;
  }
  static void update(Context c,AppWidgetManager manager,int id){
    try{
      JSONObject state=new BirthdayStore(c).data();List<JSONObject> people=BirthdayStore.sorted(state);AppWidgetProviderInfo info=manager.getAppWidgetInfo(id);if(info==null)return;
      boolean countdown=info.provider.getClassName().endsWith("CountdownWidget"),compact=info.provider.getClassName().endsWith("CompactWidget");
      RemoteViews views=new RemoteViews(c.getPackageName(),R.layout.widget);views.removeAllViews(R.id.widget_rows);
      String selected=c.getSharedPreferences("widgets",Context.MODE_PRIVATE).getString("person-"+id,"");JSONObject person=BirthdayStore.find(state,selected);if(person==null&&!people.isEmpty())person=people.get(0);
      String personId=person==null?"":person.optString("uuid");views.setOnClickPendingIntent(R.id.widget_root,link(c,personId,id));
      int height=manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,100),width=manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,140);
      boolean small=width<240,large=height>=260;
      views.setTextViewText(R.id.widget_title,countdown?"":compact||small?"NEXT BIRTHDAY":large?"UPCOMING BIRTHDAYS":"COMING UP");
      views.setViewVisibility(R.id.widget_number,countdown?View.VISIBLE:View.GONE);
      if(people.isEmpty()){
        views.setTextViewText(R.id.widget_name,"Start with someone you love");views.setTextViewText(R.id.widget_subtitle,"Tap to add a birthday");views.setViewVisibility(R.id.widget_number,View.GONE);
      }else if(countdown||compact){
        long days=BirthdayStore.days(person);views.setTextViewText(R.id.widget_name,countdown?BirthdayStore.name(person).toUpperCase(Locale.getDefault()):BirthdayStore.name(person));views.setTextViewText(R.id.widget_number,days==0?"TODAY":String.valueOf(days));
        String date=BirthdayStore.occurrence(person,2000).format(DateTimeFormatter.ofPattern("MMM d"));views.setTextViewText(R.id.widget_subtitle,countdown?(days==0?"🎉 Happy birthday":days==1?"DAY LEFT":"DAYS LEFT"):(days==0?"Today!":days+" days")+" · "+date);
        if(countdown){views.setViewVisibility(R.id.widget_title,View.GONE);views.setViewVisibility(R.id.widget_date,View.VISIBLE);views.setTextViewText(R.id.widget_date,date);for(int text:List.of(R.id.widget_name,R.id.widget_number,R.id.widget_subtitle,R.id.widget_date))views.setInt(text,"setGravity",Gravity.CENTER);views.setInt(R.id.widget_root,"setGravity",Gravity.CENTER);}
      }else{
        JSONObject nearest=people.get(0);views.setTextViewText(R.id.widget_name,small?nearest.optString("firstName",BirthdayStore.name(nearest)):BirthdayStore.name(nearest));String date=BirthdayStore.occurrence(nearest,2000).format(DateTimeFormatter.ofPattern("MMM d"));String count=BirthdayStore.days(nearest)==0?"Today":BirthdayStore.days(nearest)==1?"Tomorrow":BirthdayStore.days(nearest)+" days";
        views.setTextViewText(R.id.widget_subtitle,count);views.setTextViewTextSize(R.id.widget_subtitle,android.util.TypedValue.COMPLEX_UNIT_SP,19);views.setTextColor(R.id.widget_subtitle,0xff245c49);
        if(small||large){views.setViewVisibility(R.id.widget_avatar,View.VISIBLE);views.setImageViewBitmap(R.id.widget_avatar,avatar(nearest));views.setViewVisibility(R.id.widget_date,View.VISIBLE);views.setTextViewText(R.id.widget_date,(!nearest.isNull("birthYear")&&state.optJSONObject("settings").optBoolean("showAge",true)?"Turns "+(BirthdayStore.next(nearest,LocalDate.now()).getYear()-nearest.optInt("birthYear"))+" · ":"")+date);}else{views.setViewVisibility(R.id.widget_name,View.GONE);views.setViewVisibility(R.id.widget_subtitle,View.GONE);}
        int start=large?1:0,rows=large?6:small?0:3;
        for(int j=start;j<Math.min(start+rows,people.size());j++){
          JSONObject p=people.get(j);RemoteViews row=new RemoteViews(c.getPackageName(),R.layout.widget_row);row.setImageViewBitmap(R.id.row_avatar,avatar(p));row.setTextViewText(R.id.row_name,BirthdayStore.name(p));row.setTextViewText(R.id.row_date,BirthdayStore.occurrence(p,2000).format(DateTimeFormatter.ofPattern("MMM d")));row.setTextViewText(R.id.row_count,BirthdayStore.days(p)==0?"Today":BirthdayStore.days(p)+"d");row.setOnClickPendingIntent(R.id.row_root,link(c,p.optString("uuid"),id*100+j+10));views.addView(R.id.widget_rows,row);
        }
      }
      manager.updateAppWidget(id,views);
    }catch(Exception ignored){/* Keep the last readable widget if storage is unavailable. */}
  }
}
