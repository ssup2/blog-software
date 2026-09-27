---
title: flock System Call and Tool
---

This post explains the flock System Call, one of the System Calls of Unix Systems, and analyzes the flock Tool, a File Lock Tool built on the flock System Call in Linux.

## 1. flock() System Call

```C {caption="[Code 1] flock() System Call", linenos=table}
int flock(int fd, int operation)
```

It is a System Call that locks or unlocks a file. It uses the following Parameters.

* `fd` : Takes the File Descriptor of an opened file.
* `operation` : Specifies the operation and options to perform on `fd`. Three Operations can be given: `LOCK_SH`, `LOCK_EX`, and `LOCK_UN`. `LOCK_SH` performs a Read Lock, `LOCK_EX` performs a Write Lock, and `LOCK_UN` performs an Unlock operation. In addition, the `LOCK_NB` option allows it to be used as a Non-blocking System Call.

Unlocking is done with the `LOCK_UN` Operation, or happens automatically when `fd` is **Closed**. `fd` is closed through the `close()` System Call, or the Kernel closes `fd` when the Process that opened `fd` terminates. Therefore, in most cases, even if the Process that called the `open()` and `flock()` System Calls terminates abnormally, the Lock is naturally unlocked.

However, when the Process that opened `fd` creates a Child Process by Forking, the `fd` information is also copied at the moment of the Fork, so even if the Process that called the `flock()` System Call terminates, `fd` is not closed unless the Child Process terminates. Therefore, care must be taken when using the `flock()` System Call if a Process creates Child Processes through Fork.

## 2. flock Tool

Linux provides the flock Tool, which allows File Locks to be used from the Shell based on the flock System Call.

#### 2.1. Flow

{{< figure caption="[Figure 1] flock Tool Flow" src="images/flock-tool-flow.png" width="800px" >}}

[Figure 1] shows the execution flow of the flock Tool. Since the `O_CREAT` Option is used when opening, the Lock file is created if it does not exist. The `-x` option means performing `LOCK_EX`, and the `file.lock` file is used as the Lock file. `/bin/bash` runs exclusively.

With the `-o` option, the flock Tool closes `fd` in the Child Process after the Fork, before executing the Command. Regardless of the Command, the Lock is always unlocked when the flock Tool performs the wait operation and terminates. On the other hand, without the `-o` option, `fd` is not closed after the Fork. If the Command running in the Child Process performs a Fork and creates another Child Process, even if the flock Tool terminates, the Unlock is not performed unless the Child's Child Process closes `fd`. Therefore, the `-o` option must be used if the Command performs a Fork.

#### 2.2. Lock File Deletion

{{< figure caption="[Figure 2] Flock Lock File Deletion" src="images/flock-tool-file-delete.png" width="800px" >}}

When using the flock Tool, Lock files are only created and never deleted, causing the problem of Lock files piling up. However, Lock files must not be deleted arbitrarily from the outside. [Figure 2] shows a case where the Command may not run exclusively if the Lock file is deleted arbitrarily.

When the second flock Tool runs while the first flock Tool is running, the second flock Tool is blocked because they use the same `file.lock` file as the Lock file. (red section) After that, as the first flock Tool finishes, the second flock Tool runs. At this point, if `file.lock` is deleted before the third flock Tool runs, the third flock Tool cannot see the `file.lock` used by the second flock Tool, so the Commands can run simultaneously.

A safe way to delete Lock files is to create the Lock files on a memory file system such as tmpfs. The Lock files are naturally deleted when the PC reboots.

## 3. References

* inode Check File Lock : [http://stackoverflow.com/questions/17708885/flock-removing-locked-file-without-race-condition](http://stackoverflow.com/questions/17708885/flock-removing-locked-file-without-race-condition)
