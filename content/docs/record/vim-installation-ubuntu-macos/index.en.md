---
title: Vim Installation / Ubuntu, macOS Environment
---

## 1. Installation and Configuration Environment

The installation and configuration environment is as follows.

* Ubuntu 14.04 / Ubuntu 16.04 (root user)
* macOS 10.14
* Vim 8

## 2. Configuration Plugin List

The list of VIM plugins used is as follows.
* vundle: Serves as a Vim Plugin Manager. By placing Vim plugins to install in .vimrc, you can easily install Vim plugins through vundle.
* nerdtree: Serves as a file explorer.
* tagbar: Shows a list of code tags.
* YouCompleteMe: Performs code autocomplete functionality.
* vim-gutentags: Automatically manages Ctag files.
* vim-airline: Improves readability of Vim's status line.
* vim-clang-format: Performs code alignment using clang-format.
* vim-go: Configures the environment for golang.

## 3. Vim Basic Installation and Configuration

### 3.1. Package Installation

#### 3.1.1. Ubuntu

```shell
$ add-apt-repository ppa:jonathonf/vim
$ apt-get update
$ apt-get install vim-gnome
$ apt-get install ctags
$ apt-get install cscope
$ apt-get install clang-format
```

Install Vim, ctags, cscope, and ClangFormat.

#### 3.1.2. macOS

```shell
$ brew update
$ brew install vim
$ brew install --HEAD universal-ctags/universal-ctags/universal-ctags
$ brew install cscope
$ brew install clang-format
```

Install Vim, ctags, cscope, and ClangFormat.

### 3.2. Bash Shell Configuration

#### 3.2.1. Ubuntu

```shell {caption="[File 1] ~/.bashrc", linenos=table}
...
export TERM=xterm-256color
source "$HOME/.vim/bundle/gruvbox/gruvbox_256palette.sh"
```

Add the content from [File 1] to the ~/.bashrc file to configure Vundle to install vim-go.

### 3.3. Vundle Plugin Installation

```shell
$ git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
```

Install Vundle using git.

### 3.4. .vimrc File Configuration

```viml {caption="[File 2] ~/.vimrc", linenos=table}
"
" ssup2's .vimrc
"
" Version 1.21 for Ubuntu
"

"" vundle Setting
set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

" Plugins
Plugin 'morhetz/gruvbox'
Plugin 'scrooloose/nerdtree'
Plugin 'majutsushi/tagbar'
Plugin 'Valloric/YouCompleteMe'
Plugin 'ludovicchabant/vim-gutentags'
Plugin 'bling/vim-airline'
Plugin 'rhysd/vim-clang-format'

" All of your Plugins must be added before the following line
call vundle#end()               " required
filetype plugin indent on       " required

"" Vim Setting
set encoding=utf-8              " Encoding Type utf-8
set nu                          " Line Number
set ai                          " Auto Indent
set ts=4                        " Tab Size
set sw=4                        " Shift Width
set hlsearch                    " highlight all search matches
colorscheme gruvbox
syntax on

"" gruvbox	
set background=dark

"" cscope Setting
set csprg=/usr/bin/cscope         " cscope Which
set csto=1                        " tags Search First
set cst                           " 'Ctrl + ]' use ':cstag' instead of the default ':tag' behavior
set nocsverb                      " verbose Off
if filereadable("./cscope.out")   " add cscope.out
    cs add cscope.out
endif
set csverb                        " verbose On

"" NERD Tree Setting
nmap <F7> :NERDTreeToggle<CR>     " F7 Key = NERD Tree Toggling
let NERDTreeWinPos = "left"

"" Tag Bar Setting
nmap <F8> :TagbarToggle<CR>       " F8 Key = Tagbar Toggling

filetype on
let g:tagbar_width = 35

"" vim-gutentags
let g:gutentags_project_root = ['.tag_root']
let g:gutentags_project_info = []

"" YouCompleteMe
let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
let g:ycm_autoclose_preview_window_after_completion = 1
nnoremap <C-p> :YcmCompleter GoTo<CR>

"" vim-clang-format
autocmd FileType c,cpp,objc nnoremap <buffer><Leader>cf :<C-u>ClangFormat<CR>
autocmd FileType c,cpp,objc vnoremap <buffer><Leader>cf :ClangFormat<CR>
nmap <Leader>C :ClangFormatAutoToggle<CR>
let g:clang_format#auto_format = 0
```

Create the ~/.vimrc file as shown in [File 2] to store plugin installation and configuration information.

### 3.5. Vim Plugin Installation Using Vundle

```shell
: PluginInstall
```

Install Vim plugins stored in ~/.vimrc. Execute in Vim command mode.

### 3.6. YouCompleteMe Installation

#### 3.6.1. Ubuntu

```shell
$ apt-get install build-essential cmake
$ apt-get install python-dev python3-dev
$ cd ~/.vim/bundle/YouCompleteMe
$ ./install.py --clang-completer
```

Compile and install YouCompleteMe.

```shell
$ wget https://raw.githubusercontent.com/Valloric/ycmd/3ad0300e94edc13799e8bf7b831de8b57153c5aa/cpp/ycm/.ycm_extra_conf.py -O ~/.vim/.ycm_extra_conf.py
```

Download `.ycm_extra_conf.py` and copy it to `~/.vim/.ycm_extra_conf.py` to use as YouCompleteMe's default configuration value.

#### 3.6.2. macOS

```shell
$ brew install cmake
$ brew install python2
$ cd ~/.vim/bundle/YouCompleteMe
$ ./install.py --clang-completer
```

Compile and install YouCompleteMe.

```shell
$ wget https://raw.githubusercontent.com/Valloric/ycmd/3ad0300e94edc13799e8bf7b831de8b57153c5aa/cpp/ycm/.ycm_extra_conf.py -O ~/.vim/.ycm_extra_conf.py
```

Download `.ycm_extra_conf.py` and copy it to `~/.vim/.ycm_extra_conf.py` to use as YouCompleteMe's default configuration value.

## 4. Golang Environment Installation and Configuration

### 4.1. Golang Installation

* Install Golang and configure Golang-related environment variables.

### 4.2. vim-go Vim Plugin Installation

```viml {caption="[File 2] ~/.vimrc", linenos=table}
...
Plugin 'fatih/vim-go'
...
```

Add the content from [File 3] to Vundle Plugins in the ~/.vimrc file to configure Vundle to install vim-go.

```shell
: PluginInstall
```

Install the vim-go Vim plugin. Execute in Vim command mode.

### 4.3. Golang Binary Installation

```shell
: GoInstallBinaries
```

Install tools required for Golang development. Execute in Vim command mode.

### 4.4. YouCompleteMe Reinstallation

```shell
$ cd ~/.vim/bundle/YouCompleteMe
$ ./install.py --clang-completer --gocode-completer
```

Compile and install YouCompleteMe with the Golang option added.

## 5. Usage

### 5.1. YouCompleteMe

For C, Cpp projects, copy the ~/.vim/.ycm_extra_conf.py file to the project root folder to configure YouCompleteMe to work.

| Shortcut | Action |
|-------|------|
| ctrl + p | YouCompleteMe Tag Jump |
| ctrl + o | Move to previous jump point (VIM shortcut) |
| ctrl + i | Move to next jump point (VIM shortcut) |

### 5.2. vim-clang-format

Auto Mode is a mode that automatically applies clang-format to files when saving.

| Shortcut | Action |
|-------|------|
| \cf | Apply clang-format |
| \C | Enable/Disable Auto Mode |

### 5.3. vim-gutentags

vim-gutentags recognizes folders containing .git or .svn files as project root folders. If these files do not exist, you can create a **.tag_root** file in the project root folder to make vim-gutentags recognize the project root folder.

## 6. References

* Vundle: [https://github.com/gmarik/Vundle.vim](https://github.com/gmarik/Vundle.vim)
* Colorscheme: [https://github.com/junegunn/seoul256.vim](https://github.com/junegunn/seoul256.vim)
* YouCompleteMe Install: [http://neverapple88.tistory.com/26](http://neverapple88.tistory.com/26)

