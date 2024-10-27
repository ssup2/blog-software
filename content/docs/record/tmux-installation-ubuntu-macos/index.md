---
title: tmux 설정 / Ubuntu, macOS 환경
---

## 1. tmux 설치

### 1.1. Ubuntu

```shell
$ apt install tmux
$ git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

apt을 이용하여 tmux를 설치한다.

### 1.2. macOS

```shell
$ brew install tmux
```

brew를 이용하여 tmux를 설치한다.

## 2. tmux 설정

```text {caption="[File 1] ~/.tmux.conf", linenos=table}
# Set screen color
set -g default-terminal "screen-256color"

# Set mouse
setw -g mouse on

# Vim-like pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Vim-like search and move on scroll mode
set-window-option -g mode-keys vi

# Prevent to down scroll after mouse copy
set -g @yank-action 'copy-pipe'

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'

# Initialize TMUX plugin manager
run -b '~/.tmux/plugins/tpm/tpm'
```

`~/.tmux.conf` 파일을 [File 1]의 내용으로 생성/변경 한다.

## 3. Bash Shell, Terminal 설정

### 3.1. Ubuntu

```shell {caption="[File 2] ~/.bashrc", linenos=table}
...
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi
```

`~/.bashrc` 파일의 마지막에 [File 2]의 내용을 추가하여 Shell 실행시 tmux가 실행되도록 설정한다.

### 3.2. macOS

{{< figure caption="[Figure 1] tmux autorun setting with iTerm2" src="images/tmux-autorun-iterm2.png" width="800px" >}}

`Preferences... -> Profiles -> General -> Sends text at start:`

`tmux ls && read tmux-session && tmux attach -t ${tmux-session:-default} \|\| tmux new -s ${tmux-session:-default}`

[Figure 1]의 내용처럼 iTerm2 설정에 "Sends text at start"에 tmux 설정을 추가하여 iTerm2 실행시 tmux가 실행되도록 설정한다.

{{< figure caption="[Figure 2] tmux clipboard setting with iTerm2" src="images/tmux-clipboard-iterm2.png" width="800px" >}}

`Preferences... -> General -> Applications in terminal may access clipboard`

[Figure 2]의 내용처럼 iTerm2를 설정하여 tmux에서 선택한 Text가 Clipboard로 복사되도록 설정한다.

## 4. TPM (Tmux Plugin Manager) 설치, 실행

```shell
$ git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

TPM을 설치한다.

```shell
# tmux
ctrl + b, I
```

tmux를 실행하고, tmux 안에서 단축키를 눌러 Plugin을 설치한다.

## 5. 참조

* [https://github.com/tmux-plugins/tpm](https://github.com/tmux-plugins/tpm)
