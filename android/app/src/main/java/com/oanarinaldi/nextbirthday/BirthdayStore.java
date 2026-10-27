package com.oanarinaldi.nextbirthday;

import android.content.Context;
import android.util.AtomicFile;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;
import org.json.*;

/** Local, atomic storage shared by the app, reminders, and widgets. */
final class BirthdayStore {
  static final Object LOCK = new Object();
  final AtomicFile file;
  BirthdayStore(Context context) {file=new AtomicFile(new File(context.getFilesDir(),"birthdays.json"));}
  String read() {
    synchronized(LOCK) {
      try {return new String(file.readFully(),StandardCharsets.UTF_8);}
      catch(FileNotFoundException e) {return "";}
      catch(IOException e) {throw new IllegalStateException("Could not read birthdays",e);}
    }
  }
  JSONObject data() throws JSONException {
    String raw=read();return new JSONObject(raw.isEmpty()?"{\"schemaVersion\":1,\"revision\":0,\"people\":[],\"settings\":{}}":raw);
  }
  boolean save(String raw,int expected) {
    synchronized(LOCK) {
      FileOutputStream stream=null;
      try {
        if(raw.length()>32*1024*1024)return false;
        JSONObject s=new JSONObject(raw);
        if(s.optInt("schemaVersion")!=1||s.optInt("revision")!=expected+1||data().optInt("revision")!=expected||s.optJSONArray("people")==null||s.optJSONObject("settings")==null)return false;
        Set<String> ids=new HashSet<>();
        JSONArray people=s.getJSONArray("people");
        for(int i=0;i<people.length();i++) {
          JSONObject p=people.getJSONObject(i);
          if(p.optString("uuid").isEmpty()||!ids.add(p.optString("uuid")))return false;
          int month=p.getInt("birthMonth"),day=p.getInt("birthDay"),year=p.isNull("birthYear")?2000:p.getInt("birthYear");
          LocalDate.of(year,month,day);
          if(!Double.isFinite(p.optDouble("celebrationBudget",0))||p.optDouble("celebrationBudget",0)<0)return false;
        }
        stream=file.startWrite();stream.write(raw.getBytes(StandardCharsets.UTF_8));file.finishWrite(stream);return true;
      } catch(Exception e){if(stream!=null)file.failWrite(stream);return false;}
    }
  }
  static LocalDate occurrence(JSONObject p,int year) {
    int month=p.optInt("birthMonth",1),day=p.optInt("birthDay",1);
    YearMonth ym=YearMonth.of(year,month);return ym.atDay(Math.min(day,ym.lengthOfMonth()));
  }
  static LocalDate next(JSONObject p,LocalDate today) {
    LocalDate d=occurrence(p,today.getYear());return d.isBefore(today)?occurrence(p,today.getYear()+1):d;
  }
  static long days(JSONObject p) {LocalDate now=LocalDate.now();return ChronoUnit.DAYS.between(now,next(p,now));}
  static String name(JSONObject p) {return (p.optString("firstName")+" "+p.optString("lastName")).trim();}
  static List<JSONObject> sorted(JSONObject s) {
    List<JSONObject> result=new ArrayList<>();JSONArray a=s.optJSONArray("people");
    if(a!=null)for(int i=0;i<a.length();i++)if(a.optJSONObject(i)!=null)result.add(a.optJSONObject(i));
    result.sort(Comparator.comparingLong(BirthdayStore::days).thenComparing(BirthdayStore::name));return result;
  }
  static JSONObject find(JSONObject state,String id) {return sorted(state).stream().filter(p->p.optString("uuid").equals(id)).findFirst().orElse(null);}
}
