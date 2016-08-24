import 'dart:html';
import 'dart:convert';
InputElement toDoInput;
UListElement toDoList;

void main(){
  toDoInput = querySelector('#to-do-input');
  toDoList = querySelector('#to-do-list');
  toDoInput.onChange.listen(addToDoItem);

  loadData();
}

void addToDoItem(Event e){
  var text = toDoInput.value;
  toDoInput.value = '';
  saveData(text);
  loadData();
}

void loadData(){
  var url = "http://127.0.0.1:3001/users.json";
  // call the web server asynchronously
  var request = HttpRequest.getString(url).then(onDataLoaded);
}

void saveData(value) {
  var url = "http://127.0.0.1:3001/users.json";
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
