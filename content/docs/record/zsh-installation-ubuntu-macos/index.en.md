---
title: Zsh Installation / Ubuntu, macOS Environment
---

## 1. Zsh Installation

### 1.1. Ubuntu

```shell
$ apt install zsh
$ curl -L http://install.ohmyz.sh | sh
$ chsh -s `which zsh`
$ zsh
```

Install zsh and oh-my-zsh and set the default shell to Zsh. Proceed from **Zsh** afterwards.

### 1.2. macOS

```shell
$ brew install zsh zsh-completions
$ curl -L http://install.ohmyz.sh | sh
$ which zsh >> /etc/shells
$ chsh -s `which zsh`
$ zsh
```

Install zsh, zsh-completions, and oh-my-zsh and set the default shell to Zsh. Proceed from **Zsh** afterwards.

## 2. Zsh Plugin Download

```shell
$ git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
$ git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
$ git clone https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions
```

Install zsh-syntax-highlighting, zsh-autosuggestions, and zsh-completions.

## 3. Zsh Plugin Configuration

```viml {caption="[File 1] ~/.zshrc", linenos=table}
...
plugins=(
  git
  docker
  kubectl
  kubectx
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh
...
# Prompt
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%})"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
PROMPT+='%{$fg_bold[blue]%}k8s:(%{$fg[red]%}$(kubectx_prompt_info)%{$fg_bold[blue]%})%{$reset_color%} ' # k8s context
```

Modify the ~/.zshrc file with the content from [File 1] to configure plugins.

## 4. References

* [https://gist.github.com/ganapativs/e571d9287cb74121d41bfe75a0c864d7](https://gist.github.com/ganapativs/e571d9287cb74121d41bfe75a0c864d7)

