import 'dart:html';
//import 'dart:convert';
import 'dart:async';
import 'dart:indexed_db' as idb;

//var base_url = "http://127.0.0.1:3000/";
/**
 * Global Vars
 */
Map<int, Todo> todos;
bool show_done = false;

//InputElement toDoInput;
//UListElement toDoList;
UListElement thingsList;
InputElement thingInput;
ButtonElement clearButton;
ButtonElement showAllButton;

enum WhichTable { todo, ticking, timesheet }
enum Mode {
  r,
  rw,
}

class Config {
  static String db_name = "exsimple";
  static String todos_table_name = "todos";
  static String ticking_table_name = "ticking";
  static String timesheet_table_name = "timesheet";
  static idb.Database _db;
  static String getTableName(WhichTable whichTable) {
    String table_name;
    switch (whichTable) {
      case WhichTable.todo:
        table_name = todos_table_name;
        break;
      case WhichTable.ticking:
        table_name = ticking_table_name;
        break;
      case WhichTable.timesheet:
        table_name = timesheet_table_name;
        break;
    }
    return table_name;
  }

  static String getModeName(Mode mode) {
    String mode_name;
    switch (mode) {
      case Mode.r:
        mode_name = "readonly";
        break;
      case Mode.rw:
        mode_name = 'readwrite';
        break;
    }
    return mode_name;
  }

  static idb.Transaction transaction(WhichTable table, Mode mode) {
    String table_name = getTableName(table);
    String mode_name = getModeName(mode);
    return Config._db.transaction(table_name, mode_name);
  }

  static idb.ObjectStore store(WhichTable table, idb.Transaction transaction) {
    return transaction.objectStore(getTableName(table));
  }
}

class Todo {
  var key;
  String name;
  DateTime addedOn;
  bool done;

  Todo(String name) {
    this.name = name;
    this.addedOn = new DateTime.now();
    this.key = null;
    this.done = false;
  }

  Todo.fromRaw(dbkey, Map value)
      : key = dbkey,
        name = value['name'],
        addedOn = DateTime.parse(value['addedOn']),
        done = value['done'] {}

  Map toRaw() {
    return {'name': name, 'addedOn': addedOn.toString(), 'done': done};
  }

  void remove() {
    var transaction = Config.transaction(WhichTable.todo, Mode.rw);
    Config.store(WhichTable.todo, transaction).delete(this.key);
    return transaction.completed.then((_) {});
  }

  Future finish() {
    this.done = true;
    return _updateSelf();
  }

  Future _updateSelf() {
    var rawMap = this.toRaw();
    var transaction = Config.transaction(WhichTable.todo, Mode.rw);
    Config.store(WhichTable.todo, transaction).put(rawMap, this.key);
    return transaction.completed;
  }

  Future undone() {
    this.done = false;
    return _updateSelf();
  }

  static Future clear() {
    var transaction = Config.transaction(WhichTable.todo, Mode.rw);
    Config.store(WhichTable.todo, transaction).clear();
    return transaction.completed.then((_) {});
  }

  Future<Todo> store() {
    var rawMap = this.toRaw();
    var transaction = Config.transaction(WhichTable.todo, Mode.rw);
    var table = Config.store(WhichTable.todo, transaction);
    table.add(rawMap).then((key) {
      this.key = key;
    });
    return transaction.completed.then((_) {
      return this;
    });
  }

  static Future<Map<int, Todo>> all() {
    Map<int, Todo> todos = new Map<int, Todo>();

    var transaction = Config.transaction(WhichTable.todo, Mode.r);
    var store = Config.store(WhichTable.todo, transaction);
    var cursors = store.openCursor(autoAdvance: true).asBroadcastStream();
    cursors.listen((cursor) {
      var todo = new Todo.fromRaw(cursor.key, cursor.value);
      todos[cursor.key] = todo;
    });
    return cursors.length.then((_) {
      return todos;
    });
  }
}

void clearTodo(Event e) {
  Todo.clear().then((_) {
    todos.clear();
    renderTodos(todos);
  });
}

void addTodo(Event e) {
  var name = thingInput.value;
  thingInput.value = '';
  Todo todo = new Todo(name);
  todo.store().then((Todo todo) {
    todos[todo.key] = todo;
    renderTodos(todos);
  });
}

void doneOrUndoneTodo(Event e) {
  CheckboxInputElement box = e.target;
  var key = box.id;
  Todo todo = todos[int.parse(key)];
  if (box.checked) {
    todo.finish().then((_) {
      box.checked = true;
    });
  } else {
    todo.undone().then((_) {
      box.checked = false;
    });
  }
}

void renderTodos(Map<int, Todo> todos) {
  thingsList.children.clear();
  for (var todo in todos.values) {
    if (!show_done && todo.done) {
      continue;
    }
    var newToDo = new LIElement();
    var div = new DivElement();

    var checkBox = new CheckboxInputElement();
    var radioButton = new RadioButtonInputElement();
    var innerDiv = new DivElement();
    innerDiv.text = todo.name;
    innerDiv.style.setProperty("display", 'inline-block');
    radioButton.checked = false;
    checkBox.id = todo.key;
    checkBox.onChange.listen(doneOrUndoneTodo);

    if (todo.done) {
      checkBox.checked = true;
    }
    div.children.add(radioButton);
    div.children.add(innerDiv);
    div.children.add(checkBox);
    //div.children.add(newToDo);
    newToDo.children.add(div);
    //div.children.add(checkBox);
    thingsList.children.add(newToDo);
  }
}

Future<idb.Database> open(String db_name) {
  return window.indexedDB
      .open(db_name, version: 1, onUpgradeNeeded: _initializeDatabase)
      .then(_loadFromDB);
}

void _loadFromDB(idb.Database db) {
  Config._db = db;
  Todo.all().then((Map<int, Todo> loadedTodos) {
    todos = loadedTodos;
    renderTodos(todos);
  });
}

void main() {
  thingsList = querySelector('#things');
  thingInput = querySelector('#thing-input');
  clearButton = querySelector('#clear');
  showAllButton = querySelector('#show-all');

  thingInput.placeholder = "Input the TODO, enter to finish.";
  if (idb.IdbFactory.supported) {
    open(Config.db_name);
  } else {
    window.alert("Not supported browser....asshole");
    return;
  }

  thingInput.onChange.listen(addTodo);
  clearButton.onClick.listen(clearTodo);
  showAllButton.onClick.listen(toggleShowAll);
  //loadThings();
}


void toggleShowAll(Event e) {
  ButtonElement btn = e.target;
  if (show_done) {
    show_done = false;
    btn.text = "Show ALL";
    renderTodos(todos);
  } else {
    show_done = true;
    btn.text = "Show Unfinished only";
    renderTodos(todos);
  }
}
/*
 * structure of this small app
 *
 * 1. TODOs
 * 2. indexedDB
 * 3. init_db, add_todo, done_todo, tick-tock
 */

void _initializeDatabase(idb.VersionChangeEvent e) {
  idb.Database db = (e.target as idb.Request).result;
  var todoOjectStore =
      db.createObjectStore(Config.todos_table_name, autoIncrement: true);
  var tickingObjectStore = db.createObjectStore(Config.ticking_table_name);
  var timesheetObjectStore =
      db.createObjectStore(Config.timesheet_table_name, autoIncrement: true);
  // objectStore.createIndex(NAME_INDEX, 'milestoneName', unique: true);
}

/* Trash
void addThing(Event e) {
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
  Thing.fromJson(Map json) {
    this.title = json['title'];
    this.user_id = json['user_id'];
  }

  static Future<List<Thing>> all() async {
    var url = base_url + "things.json";
    String json_string = await HttpRequest.getString(url);
    List<Map> json_things = JSON.decode(json_string);
    List<Thing> ret = new List<Thing>();
    for (var json_thing in json_things) {
      ret.add(new Thing.fromJson(json_thing));
    }
    return ret;
  }

  void save() {
    var url = base_url + "things.json";
    HttpRequest request = new HttpRequest();
    request.open("POST", url, async: false);
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

void mountThings(List<Thing> things) {
  thingsList.children.clear();
  for (var thing in things) {
    thingsList.append(newThingItem(thing));
  }
}

LIElement newThingItem(Thing thing) {
  var li = new LIElement();
  var div = new DivElement();
  div.text = thing.title;
  li.children.add(div);
  return li;
}

void loadThings() {
  Thing.all().then(mountThings).catchError((e) => print(e));
}

void addToDoItem(Event e) {
  var text = toDoInput.value;
  toDoInput.value = '';
  saveData(text);
  loadData();
}

void loadData() {
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
  user["password_confirmation"] = "asdfgg";
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
*/
