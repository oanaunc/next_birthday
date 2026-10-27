package com.oanarinaldi.nextbirthday;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.net.Uri;
import androidx.core.app.NotificationCompat;
import java.time.*;
import java.util.*;
import org.json.*;

/** Alarm-driven local reminders. No server, exact-alarm permission, or periodic polling service. */
public final class ReminderReceiver extends BroadcastReceiver {
  static final String ACTION="com.oanarinaldi.nextbirthday.REMIND";
  record Reminder(JSONObject person,int offset,ZonedDateTime time){}
  static List<Reminder> reminders(JSONObject state,ZonedDateTime from) {
    List<Reminder> result=new ArrayList<>();JSONObject settings=state.optJSONObject("settings");
    int hour=Math.max(0,Math.min(23,settings.optInt("notificationHour",9))),minute=Math.max(0,Math.min(59,settings.optInt("notificationMinute",0)));
    JSONArray defaults=settings.optJSONArray("defaultReminderDays");if(defaults==null)defaults=new JSONArray(List.of(7,1,0));
    for(JSONObject person:BirthdayStore.sorted(state)){
      JSONArray offsets=person.optBoolean("usesCustomReminders")?person.optJSONArray("customReminderDays"):defaults;if(offsets==null)continue;
      for(int i=0;i<offsets.length();i++){
        int offset=offsets.optInt(i,-1);if(!List.of(0,1,3,7,14,30).contains(offset))continue;
        for(int y=from.getYear();y<=from.getYear()+2;y++){
          ZonedDateTime time=BirthdayStore.occurrence(person,y).minusDays(offset).atTime(hour,minute).atZone(from.getZone());
          if(time.isAfter(from)){result.add(new Reminder(person,offset,time));break;}
        }
      }
    }
    result.sort(Comparator.comparing(Reminder::time));return result;
  }
  static void schedule(Context c){
    try{
      ZonedDateTime now=ZonedDateTime.now();List<Reminder> future=reminders(new BirthdayStore(c).data(),now);
      long wake=now.toLocalDate().plusDays(1).atStartOfDay(now.getZone()).plusMinutes(1).toInstant().toEpochMilli();
      if(!future.isEmpty())wake=Math.min(wake,future.get(0).time().toInstant().toEpochMilli());
      PendingIntent pi=PendingIntent.getBroadcast(c,51,new Intent(c,ReminderReceiver.class).setAction(ACTION),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
      ((AlarmManager)c.getSystemService(Context.ALARM_SERVICE)).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,wake,pi);
    }catch(Exception ignored){/* Never replace or clear an unreadable birthday database. */}
  }
  @Override public void onReceive(Context c,Intent i){
    if(ACTION.equals(i.getAction()))deliver(c);
    BirthdayWidget.updateAll(c);schedule(c);
  }
  static void deliver(Context c){
    if(android.os.Build.VERSION.SDK_INT>=33&&c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return;
    try{
      JSONObject state=new BirthdayStore(c).data();boolean smart=state.getJSONObject("settings").optBoolean("smartRemindersEnabled",true);
      NotificationManager manager=c.getSystemService(NotificationManager.class);manager.createNotificationChannel(new NotificationChannel("birthdays","Birthday reminders",NotificationManager.IMPORTANCE_DEFAULT));
      ZonedDateTime now=ZonedDateTime.now();android.content.SharedPreferences sent=c.getSharedPreferences("reminder_delivery",Context.MODE_PRIVATE);
      for(Reminder r:reminders(state,now.minusHours(24))){
        if(r.time().isAfter(now))break;
        JSONObject p=r.person();String key=p.optString("uuid")+":"+r.offset();String stamp=r.time().toLocalDate().toString();if(stamp.equals(sent.getString(key,"")))continue;
        String first=p.optString("firstName").isBlank()?BirthdayStore.name(p):p.optString("firstName");
        Integer age=p.isNull("birthYear")?null:r.time().toLocalDate().plusDays(r.offset()).getYear()-p.optInt("birthYear");
        String title,body,when=r.offset()==1?"tomorrow":"in "+r.offset()+" days";
        if(r.offset()==0){title="🎉 It's "+first+"'s birthday today!";body=age==null?"Time to wish "+first+" a happy birthday.":first+" turns "+age+" today. Send a message or give them a call.";}
        else if(!smart){title=age==null?"🎂 "+first+"'s birthday is "+when+".":"🎂 "+first+" turns "+age+" "+when+".";body=BirthdayStore.occurrence(p,2000).format(java.time.format.DateTimeFormatter.ofPattern("MMMM d"));}
        else if(r.offset()==1){title=age==null?"🎂 "+first+"'s birthday is tomorrow":"🎂 "+first+" turns "+age+" tomorrow";body="Get your message ready.";}
        else if(r.offset()==3){title="🛍️ Time to get "+first+"'s gift";body="Only 3 days left before "+first+"'s birthday.";}
        else{title="🎁 Gift idea for "+first+"?";body=first+"'s birthday is "+when+". A good moment to start thinking about a gift.";}
        Intent intent=new Intent(c,MainActivity.class).setData(Uri.parse("nextbirthday://person/"+p.optString("uuid"))).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent content=PendingIntent.getActivity(c,key.hashCode(),intent,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        manager.notify(key.hashCode(),new NotificationCompat.Builder(c,"birthdays").setSmallIcon(R.drawable.ic_notification).setContentTitle(title).setContentText(body).setStyle(new NotificationCompat.BigTextStyle().bigText(body)).setColor(0xff245c49).setContentIntent(content).setAutoCancel(true).setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build());
        sent.edit().putString(key,stamp).apply();
      }
    }catch(Exception ignored){/* A bad record must not crash a system broadcast. */}
  }
}
