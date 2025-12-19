---
title: Linux Signal, Signal Handler
---

Analyze Linux Signals and Signal Handlers.

## 1. Signal

{{< table caption="[Table 1] Linux Signal" >}}
| Signal | Default Action | Description |
|--------|----------------|-------------|
| SIGTERM | Term | An Interrupt occurred due to Keyboard input. |
| SIGSEGV | Core | A Segmentation Fault occurred due to invalid Memory address reference. |
| SIGCHILD | Ign | Child Process terminated. |
| SIGKILL | Term | Forcibly terminates Process that received SIGKILL. |
{{< /table >}}

In Linux, Signal is one of the representative techniques for delivering Events to Processes. [Table 1] describes some Signals supported in Linux. Processes that receive Signals handle them by ignoring received Signals through **Signal Mask**, performing **Default Actions** defined for each Signal, or performing **Signal Handlers** registered in Processes. However, **SIGKILL** Signal Handlers cannot be registered in Processes. This is because Processes that receive SIGKILL are forcibly killed immediately by the Linux Kernel. Default Actions exist in 4 types: Term, Stop, Core, and Ign as follows.

* `Term` (Terminate) : Terminates Process.
* `Stop` : Puts Process in Paused state.
* `Core` : Terminates Process and leaves Core file.
* `Ign` (Ignore) : Ignores Signal.

## 2. Signal Handler

{{< figure caption="[Figure 1] Signal Handler Execution Process" src="images/linux-signal-handler-process.png" width="500px" >}}

[Figure 1] shows the execution process of Signal Handler. A Thread running an App in User Mode enters Kernel Mode due to Trap occurrence to handle the Trap. After Trap handling is complete, before entering User Mode, the Thread checks whether the Thread's Process has received Signals through `do-signal()` function call. If there are received Signals, it checks whether Signal Handlers that handle the received Signals are registered. If Signal Handlers are registered, the `setup-frame()` function manipulates the Stack where the Thread's User Mode Context is stored so that when the Thread enters User Mode, Signal Handler runs instead of App, and makes it call `sigreturn` System Call after Signal Handler execution is complete. Then the Thread enters User Mode.

The Thread that entered User Mode executes Signal Handler due to manipulation of the Thread's User Mode Stack and calls `sigreturn` System Call to enter Kernel Mode again. The Thread that entered Kernel Mode restores the User Mode Stack to its state before being changed by the `setup-frame()` function through `restore-sigcontext()` function. Then the Thread enters User Mode and executes App.

### 2.1. with Multithread

### 2.2. signal() vs sigaction()

## 3. References

* Signal : [http://man7.org/linux/man-pages/man7/signal.7.html](http://man7.org/linux/man-pages/man7/signal.7.html)
* Signal Handler : Understanding the Linux Kernel
* Signal Handler : [https://www.joinc.co.kr/w/Site/system-programing/Book-LSP/ch06-Signal](https://www.joinc.co.kr/w/Site/system-programing/Book-LSP/ch06-Signal)
* Signal Handler : [https://devarea.com/linux-handling-signals-in-a-multithreaded-application/#.XKtY6JgzaiM](https://devarea.com/linux-handling-signals-in-a-multithreaded-application/#.XKtY6JgzaiM)
* Signal Handler : [http://egloos.zum.com/studyfoss/v/5182475](http://egloos.zum.com/studyfoss/v/5182475)

