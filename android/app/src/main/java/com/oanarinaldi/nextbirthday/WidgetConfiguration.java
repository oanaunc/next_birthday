package com.oanarinaldi.nextbirthday;
import android.app.*;
import android.appwidget.*;
import android.content.*;
import android.os.Bundle;
import java.util.*;
import org.json.*;
public final class WidgetConfiguration extends Activity {
  @Override public void onCreate(Bundle state){
    super.onCreate(state);setResult(RESULT_CANCELED);int id=getIntent().getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,AppWidgetManager.INVALID_APPWIDGET_ID);if(id==AppWidgetManager.INVALID_APPWIDGET_ID){finish();return;}
    try{
      List<JSONObject> people=BirthdayStore.sorted(new BirthdayStore(this).data());List<String> names=new ArrayList<>();names.add("Next upcoming birthday");for(JSONObject p:people)names.add(BirthdayStore.name(p));
      new AlertDialog.Builder(this).setTitle("Countdown person").setItems(names.toArray(new String[0]),(d,which)->{getSharedPreferences("widgets",MODE_PRIVATE).edit().putString("person-"+id,which==0?"":people.get(which-1).optString("uuid")).apply();BirthdayWidget.update(this,AppWidgetManager.getInstance(this),id);setResult(RESULT_OK,new Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id));finish();}).setOnCancelListener(d->finish()).show();
    }catch(Exception e){finish();}
  }
}
