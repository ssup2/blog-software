---
title: macOS Keyborad, Mouse Key 설정
---

## 1. 설치 환경

설정 환경을 다음과 같다.
* macOS 10.14.6 Mojave
* Dell KM717 Keyborad, Mouse

## 2. Karabiner-Elements 설치

Key 변경을 위해서 Karabiner-Elements을 설치한다.
* https://karabiner-elements.pqrs.org/

## 3. Karabiner-Elements의 Complex Modification Rules 파일 생성

```json {caption="[File 1] ~/.config/karabiner/assets/complex-modifications/lang.json", linenos=table}
{
  "title": "Change language with right command and lang1",
  "rules": [
    {
      "description": "Change language with right command and lang1",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key-code": "right-command"
          },
          "to": [
            {
              "key-code": "caps-lock"
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key-code": "lang1"
          },
          "to": [
            {
              "key-code": "caps-lock"
            }
          ]
        }
      ]
    }
  ]
}
```

[File 1]을 생성한다. [File 1]은 Mac Keyboard의 오른쪽 Command Key와 Windows Keyboard의 한영 Key를 한글 영어 전환키로 설정한다.

```json {caption="[File 2] ~/.config/karabiner/assets/complex-modifications/mouse-space.json", linenos=table}
{
  "title": "Switch space with mouse buttons 3,4",
  "rules": [
    {
      "description": "Maps button 3 to right space switch, 4 to left space switch",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "pointing-button": "button4"
          },
          "to": [
            {
              "key-code": "left-arrow",
              "modifiers": "left-control"
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "pointing-button": "button3"
          },
          "to": [
            {
              "key-code": "right-arrow",
              "modifiers": "left-control"
            }
          ]
        }
      ]
    }
  ]
}
```

[File 2]를 생성한다. [File 2]는 Windows Mouse의 Wheel Scroll Key와 Size Key를 통해서 macOS에서 Work Space를 변경할 수 있도록 설정한다.

## 4. Karabiner-Elements의 Complex Modification Rules 설정

{{< figure caption="[Figure 1] Complex Modification Rules 설정전" src="images/karabiner-elements-complex-modification-rules-before-setting.png" width="900px" >}}

{{< figure caption="[Figure 2] Complex Modification Rules 설정후" src="images/karabiner-elements-complex-modification-rules-after-setting.png" width="900px" >}}

Karabiner-Elements에서 [File 1], [File 2]의 Complex Modification Rules을 적용한다. [Figure 1]에서 "Add rule" Button을 눌러 설정한다.