import 'dart:html';
import 'dart:convert';
import 'dart:async';

InputElement toDoInput;
UListElement toDoList;
UListElement thingsList;
InputElement thingInput;
var base_url = "http://127.0.0.1:3001/";

void main(){
  thingsList = querySelector('#things');
  thingInput = querySelector('#thing-input');
  thingInput.onChange.listen(addThing);
  loadThings();
}

void addThing(Event e){
  var text = thingInput.value;
  thingInput.value = '';
  Map m = new Map();
  m['title'] = text;
  m['user_id'] = 1;
  Thing t = new Thing.fromJson(m);
  t.save();
  loadThings();
}

class Thing {
  String title;
  int user_id;
  Thing.fromJson(Map json){
    this.title = json['title'];
    this.user_id = json['user_id'];
  }

  static Future<List<Thing>> all() async{
    var url = base_url + "things.json";
    String json_string = await HttpRequest.getString(url);
    List<Map> json_things = JSON.decode(json_string);
    List<Thing> ret = new List<Thing>();
    for(var json_thing in json_things){
      ret.add(new Thing.fromJson(json_thing));
    }
    return ret;
  }

  void save(){
    var url = base_url + "things.json";
    HttpRequest request = new HttpRequest();
    request.open("POST", url, async: true);
    request.setRequestHeader('Content-Type', 'application/json');

    var mapData = new Map();
    var thing = new Map();

    thing["title"] = this.title;
    thing["user_id"] = this.user_id;
    mapData["thing"] = thing;
    String jsonData = JSON.encode(mapData); // convert map to String
    request.send(jsonData); // perform the async POST
  }
}

void mountThings(List<Thing> things){
  thingsList.children.clear();
  for(var thing in things){
    thingsList.append(newThingItem(thing));
  }
}

LIElement newThingItem(Thing thing){
  var li = new LIElement();
  var div = new DivElement();
  div.text = thing.title;
  li.children.add(div);
  return li;
}

void loadThings(){
  Thing.all().then(mountThings).catchError((e)=>print(e));
}

void addToDoItem(Event e){
  var text = toDoInput.value;
  toDoInput.value = '';
  saveData(text);
  loadData();
}

void loadData(){
  var url = base_url + "users.json";
  // call the web server asynchronously
  HttpRequest.getString(url).then(onDataLoaded);
}

void saveData(value) {
  var url = base_url + "users.json";
  HttpRequest request = new HttpRequest();
  request.open("POST", url, async: true);
  request.setRequestHeader('Content-Type', 'application/json');


  var mapData = new Map();
  var user = new Map();

  user["name"] = value;
  user["password"] = "asdfgg";
  user["password_confirmation"]= "asdfgg";
  mapData["user"] = user;
  String jsonData = JSON.encode(mapData); // convert map to String
  request.send(jsonData); // perform the async POST
}

void onDataLoaded(String responseText) {
  toDoList.children.clear();

  List users = JSON.decode(responseText);
  for (var user in users) {
    var newToDo = new LIElement();
    newToDo.text = user['name'];
    var checkBox = new CheckboxInputElement();
    var div = new DivElement();
    div.children.add(newToDo);
    div.children.add(checkBox);
    toDoList.children.add(div);
  }
}
