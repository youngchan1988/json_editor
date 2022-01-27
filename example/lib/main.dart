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
                    )
                  ],
                ),
                Expanded(
                  child: Theme(
                    data: _darkMode ? ThemeData.dark() : ThemeData.light(),
                    child: JsonEditor(
                      enabled: true,
                      jsonString: '''
                      {
                        // This is a comment
                        "name": "young chan",
                        "number": 100,
                        "boo": true,
                        "user": {"age": 20, "tall": 1.8},
                        "cities": ["beijing", "shanghai", "shenzhen"]
                      }
                      // ''',
                      // jsonValue: const {
                      //   "name": "young",
                      //   "number": 100,
                      //   "boo": true,
                      //   "user": {"age": 20, "tall": 1.8},
                      //   "cities": ["beijing", "shanghai", "shenzhen"]
                      // },
                      onValue: (value) {
                        print(value);
                      },
                    ),
                  ),
                )
              ],
            )));
  }
}
