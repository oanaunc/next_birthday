package com.oanarinaldi.nextbirthday;

import static org.junit.Assert.*;
import android.content.Context;
import androidx.test.platform.app.InstrumentationRegistry;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.*;
import org.json.*;
import org.junit.*;

public class DeviceIntegrationTest {
  Context context;BirthdayStore store;String original;
  @Before public void before(){context=InstrumentationRegistry.getInstrumentation().getTargetContext();store=new BirthdayStore(context);original=store.read();store.file.delete();}
  @After public void after()throws Exception{store.file.delete();if(!original.isEmpty()){java.io.FileOutputStream out=store.file.startWrite();out.write(original.getBytes(StandardCharsets.UTF_8));store.file.finishWrite(out);}}
  JSONObject fixture()throws Exception{return new JSONObject("{\"schemaVersion\":1,\"revision\":1,\"settings\":{\"notificationHour\":9,\"notificationMinute\":0,\"defaultReminderDays\":[7,1,0]},\"people\":[{\"uuid\":\"person-test\",\"firstName\":\"Emma\",\"lastName\":\"Johnson\",\"birthMonth\":2,\"birthDay\":29,\"birthYear\":null,\"celebrationBudget\":40,\"customReminderDays\":[],\"usesCustomReminders\":false}]}");}
  @Test public void atomicSaveAndRevisionConflict()throws Exception{JSONObject s=fixture();assertTrue(store.save(s.toString(),0));assertEquals(1,store.data().getInt("revision"));JSONObject stale=fixture();stale.put("revision",2);assertFalse(store.save(stale.toString(),0));assertEquals(1,store.data().getInt("revision"));}
  @Test public void malformedAndDuplicateRecordsCannotOverwrite()throws Exception{JSONObject s=fixture();assertTrue(store.save(s.toString(),0));String saved=store.read();assertFalse(store.save("{broken",1));JSONObject bad=fixture();bad.put("revision",2);bad.getJSONArray("people").getJSONObject(0).put("birthMonth",13);assertFalse(store.save(bad.toString(),1));JSONObject dup=fixture();dup.put("revision",2);dup.getJSONArray("people").put(dup.getJSONArray("people").getJSONObject(0));assertFalse(store.save(dup.toString(),1));assertEquals(saved,store.read());}
  @Test public void nativeLeapYearMatchesPortableModel()throws Exception{JSONObject p=fixture().getJSONArray("people").getJSONObject(0);assertEquals(LocalDate.of(2027,2,28),BirthdayStore.occurrence(p,2027));assertEquals(LocalDate.of(2028,2,29),BirthdayStore.next(p,LocalDate.of(2027,3,1)));}
  @Test public void remindersRollForwardUsingLocalWallClockAcrossDST()throws Exception{JSONObject s=fixture();JSONObject p=s.getJSONArray("people").getJSONObject(0);p.put("birthMonth",3).put("birthDay",30);ZonedDateTime now=ZonedDateTime.of(2026,3,28,12,0,0,0,ZoneId.of("Europe/Bucharest"));List<ReminderReceiver.Reminder> rs=ReminderReceiver.reminders(s,now);assertEquals(3,rs.size());assertEquals(29,rs.get(0).time().getDayOfMonth());assertEquals(9,rs.get(0).time().getHour());assertEquals(ZoneOffset.ofHours(3),rs.get(0).time().getOffset());for(var r:rs)assertTrue(r.time().isAfter(now));}
  @Test public void customEmptyRemindersDisableOnlyThatPerson()throws Exception{JSONObject s=fixture();s.getJSONArray("people").getJSONObject(0).put("usesCustomReminders",true);assertTrue(ReminderReceiver.reminders(s,ZonedDateTime.now()).isEmpty());}
  @Test public void proEntitlementsAreSeparateFromBackupData()throws Exception{context.getSharedPreferences("play_entitlement",Context.MODE_PRIVATE).edit().clear().commit();JSONObject s=fixture().put("isPro",true);assertTrue(store.save(s.toString(),0));assertFalse(new Entitlements(context).isPro());}
  @Test public void allWidgetsUseSupportedAndroidViews(){BirthdayWidget.updateAll(context);assertNotNull(context.getResources().getLayout(R.layout.widget));assertNotNull(context.getResources().getXml(R.xml.widget_countdown));}
}
