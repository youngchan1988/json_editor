 ![img](https://tva1.sinaimg.cn/large/008i3skNgy1gysaom8718j322c0u0408.jpg)

## Features

1. Support add comment;
2. Support show errors for invalid json text;
3. Pretty format json text;
4. Output the decoded Map or List object;

## Getting started

```yaml
dependencies:
    json_editor: ^0.0.1
```

## Screen Shot

![](https://tva1.sinaimg.cn/large/008i3skNgy1gysber4x5tj318f0u0ta7.jpg)

![](https://tva1.sinaimg.cn/large/008i3skNgy1gyscug2rpbg30qo0f0nh5.gif)

## Usage

You can initial with json text:

```dart
import 'package:json_edior/json_editor.dart';

JsonEditor.string(
    jsonString: '''
        {
            // This is a comment
            "name": "young chan",
            "number": 100,
            "boo": true,
            "user": {"age": 20, "tall": 1.8},
            "cities": ["beijing", "shanghai", "shenzhen"]
         }
    ''',
    onValueChanged: (value) {
        print(value);
    },
)

```

Or initial with json object:

```dart
import 'package:json_editor/json_editor.dart';

JsonEditor.object(
    object: const {
        "name": "young",
        "number": 100,
        "boo": true,
        "user": {"age": 20, "tall": 1.8},
        "cities": ["beijing", "shanghai", "shenzhen"]
    },
    onValueChanged: (value) {
        print(value);
    },
)
```

Or initial with JsonElement:

```dart
import 'package:json_editor/json_editor.dart';

JsonEditor.element(
    element: JsonElement(
            value: [
              JsonElement(
                  key: "name",
                  value: "YoungChan",
                  valueType: JsonElementValueType.string,
                  comment: "A comment")
            ],
            valueType: JsonElementValueType.map,
          ),
    onValueChanged: (value) {
        print(value);
    },
)
```

The `onValueChanged` output a Map or a List object. If there is some errors in json text. The closure will not be called.

### Theme

If you want to custom the json theme. You can use `JsonEditorTheme` widget.

```dart
JsonEditorTheme(
    themeData: JsonEditorThemeData(
        lightTheme: JsonEditorThemeData.defaultTheme().lightTheme.copyWith(bracketStyle: TextStyle(color: Colors.amber, fontSize: 16)),
        darkTheme: JsonEditorThemeData.defaultTheme().darkTheme
    ),
    child: JsonEditor.string(
            jsonString: '''
                {
                    // This is a comment
                    "name": "young chan",
                    "number": 100,
                    "boo": true,
                    "user": {"age": 20, "tall": 1.8},
                    "cities": ["beijing", "shanghai", "shenzhen"]
                }
            ''',
            onValueChanged: (value) {
                print(value);
            },
        )
)
```


# License

See [LICENSE](LICENSE)
