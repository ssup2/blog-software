---
title: macOS Keyboard and Mouse Key Configuration
---

## 1. Installation Environment

The configuration environment is as follows.
* macOS 10.14.6 Mojave
* Dell KM717 Keyboard, Mouse

## 2. Karabiner-Elements Installation

Install Karabiner-Elements to change keys.
* https://karabiner-elements.pqrs.org/

## 3. Karabiner-Elements Complex Modification Rules File Creation

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

Create [File 1]. [File 1] sets the Mac keyboard's right Command key and Windows keyboard's language key as Korean/English toggle keys.

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

Create [File 2]. [File 2] configures Windows mouse wheel scroll key and side key to change macOS workspace.

## 4. Karabiner-Elements Complex Modification Rules Configuration

{{< figure caption="[Figure 1] Before Complex Modification Rules Configuration" src="images/karabiner-elements-complex-modification-rules-before-setting.png" width="900px" >}}

{{< figure caption="[Figure 2] After Complex Modification Rules Configuration" src="images/karabiner-elements-complex-modification-rules-after-setting.png" width="900px" >}}

Apply the Complex Modification Rules from [File 1] and [File 2] in Karabiner-Elements. Click the "Add rule" button in [Figure 1] to configure.

