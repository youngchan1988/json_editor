// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

import 'package:json_editor/json_editor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _darkMode = false;
  JsonElement? _elementResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: _darkMode
            ? ThemeData.dark().scaffoldBackgroundColor
            : ThemeData.light().scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('JsonEditor'),
        ),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Switch(
                        value: _darkMode,
                        onChanged: (b) {
                          setState(() {
                            _darkMode = b;
                          });
                        }),
                    const SizedBox(width: 8),
                    Text(
                      'Dark Mode',
                      style: TextStyle(
                          color: _darkMode ? Colors.white : Colors.black),
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => ObjectDemoPage(
                                    obj: _elementResult?.toObject(),
                                  )));
                        },
                        child: const Text('Object Demo')),
                    const SizedBox(
                      width: 16,
                    ),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => ElementDemoPage(
                                    element: _elementResult,
                                  )));
                        },
                        child: const Text('Element Demo')),
                  ],
                ),
                Expanded(
                  child: Theme(
                    data: _darkMode ? ThemeData.dark() : ThemeData.light(),
                    child: JsonEditorTheme(
                      themeData: JsonEditorThemeData(
                        lightTheme: JsonTheme.light().copyWith(
                            commentStyle: const TextStyle(fontSize: 25)),
                      ),
                      child: JsonEditor.string(
                        // jsonString: '''
                        // {
                        //   // This is a comment
                        //   "name": "young chan",
                        //   "number": 100,
                        //   "boo": true,
                        //   "user": {"age": 20, "tall": 1.8},
                        //   "cities": ["beijing", "shanghai", "shenzhen"]
                        // }''',
                        initialString: '''
                        {
                          // This is a comment
                          "name": "young chan",
                          "number": 100,
                          "boo": true,
                          "user": {"age": 20, "tall": 1.8},
                          "cities": ["beijing", "shanghai", "shenzhen"]
                        }''',
                        onValueChanged: (value) {
                          _elementResult = value;
                          print(value);
                        },
                      ),
                    ),
                  ),
                )
              ],
            )));
  }
}

class ObjectDemoPage extends StatelessWidget {
  const ObjectDemoPage({Key? key, this.obj}) : super(key: key);

  final Object? obj;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: JsonEditor.object(
          object: obj,
          onValueChanged: (value) {
            var json = value.toJson();
            print(json);
            var fromJson = JsonElement.fromJson(json);
            print(fromJson);
          },
        ),
      ),
    );
  }
}

class ElementDemoPage extends StatelessWidget {
  const ElementDemoPage({Key? key, this.element}) : super(key: key);

  final JsonElement? element;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Element Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: JsonEditor.element(
          element: element,
          onValueChanged: (value) {
            var json = value.toJson();
            print(json);
            var fromJson = JsonElement.fromJson(json);
            print(fromJson);
          },
        ),
      ),
    );
  }
}
