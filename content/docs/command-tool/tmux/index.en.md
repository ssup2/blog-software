---
title: tmux
---

This document summarizes the usage of tmux, a Terminal Multiplexer.

## 1. tmux

### 1.1. Session Shortcuts

* `tmux new -s [session-name]` : Create a session
* `tmux ls` : List sessions
* `tmux attach -t [session-name or session-number]` : Attach to a session
* ctrl + b, d : Detach from session

### 1.2. Window Shortcuts

* ctrl + b, c : Create a window
* ctrl + b, 0~9 : Switch to window by number
* ctrl + b, n : Switch to next window
* ctrl + b, p : Switch to previous window
* ctrl + b, l : Switch to last window
* ctrl + b, w : Open window selector

### 1.3. Pane

* ctrl + b, % : Split horizontally
* ctrl + b, " : Split vertically
* ctrl + b, arrow keys : Move between panes

### 1.4. ETC

* ctrl + b, ? : Show shortcut list

## 2. References

* [https://edykim.com/ko/post/tmux-introductory-series-summary/](https://edykim.com/ko/post/tmux-introductory-series-summary/)

