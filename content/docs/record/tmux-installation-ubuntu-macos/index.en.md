---
title: tmux Configuration / Ubuntu, macOS Environment
---

## 1. tmux Installation

### 1.1. Ubuntu

```shell
$ apt install tmux
$ git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Install tmux using apt.

### 1.2. macOS

```shell
$ brew install tmux
```

Install tmux using brew.

## 2. tmux Configuration

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

Create/modify the `~/.tmux.conf` file with the content from [File 1].

## 3. Bash Shell and Terminal Configuration

### 3.1. Ubuntu

```shell {caption="[File 2] ~/.bashrc", linenos=table}
...
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi
```

Add the content from [File 2] to the end of the `~/.bashrc` file to configure tmux to run when the shell starts.

### 3.2. macOS

{{< figure caption="[Figure 1] tmux autorun setting with iTerm2" src="images/tmux-autorun-iterm2.png" width="800px" >}}

`Preferences... -> Profiles -> General -> Sends text at start:`

`tmux ls && read tmux-session && tmux attach -t ${tmux-session:-default} \|\| tmux new -s ${tmux-session:-default}`

Configure iTerm2 settings as shown in [Figure 1] by adding tmux configuration to "Sends text at start" so that tmux runs when iTerm2 starts.

{{< figure caption="[Figure 2] tmux clipboard setting with iTerm2" src="images/tmux-clipboard-iterm2.png" width="800px" >}}

`Preferences... -> General -> Applications in terminal may access clipboard`

Configure iTerm2 as shown in [Figure 2] so that text selected in tmux is copied to the clipboard.

## 4. TPM (Tmux Plugin Manager) Installation and Execution

```shell
$ git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Install TPM.

```shell
# tmux
ctrl + b, I
```

Run tmux and press the shortcut keys inside tmux to install plugins.

## 5. References

* [https://github.com/tmux-plugins/tpm](https://github.com/tmux-plugins/tpm)

