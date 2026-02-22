---
title: NVIDIA GPU Sharing
---

## 1. NVIDIA GPU Sharing

GPU Sharing is a technique that allows multiple processes to share a single GPU. There are three main techniques: **Time-Slicing**, **MPS**, and **MIG**.

{{< figure caption="[Figure 1] Example Applications" src="images/example-apps.png" width="900px" >}}

[Figure 1] shows example applications for examining GPU Sharing techniques. There are three CUDA Apps: A, B, and C, each with 2 CUDA Streams. That is, they are configured to execute a maximum of 2 CUDA kernels simultaneously.

Within a CUDA App, the kernel on the left represents a kernel submitted earlier than the kernel on the right, and a longer kernel means it runs for a longer duration. For example, in App A, three kernels `A1`, `A2`, and `A3` were submitted first, followed by the `A4` kernel. Also, kernels `A1` and `A3` run approximately twice as long as kernels `A2` and `A4`.

### 1.1. Time-slicing

{{< figure caption="[Figure 2] Time-Slicing Architecture" src="images/time-slicing-architecture.png" width="600px" >}}

**Time-slicing** is a technique that allows multiple CUDA apps to share a GPU through **time division** via **GPU Context Switch**, as the name suggests. It is similar to how multiple apps share a single CPU through time division. [Figure 2] shows the structure of the Time-slicing technique. Just as a process's context is stored in memory (stack), the GPU's context is stored in GPU memory.

Time-slicing is the most basic GPU sharing technique, and CUDA apps do not need to modify any logic for separate time slices. When multiple CUDA apps access the GPU simultaneously, the GPU device driver and GPU automatically apply the Time-slicing technique to allow multiple CUDA apps to share the GPU.

{{< figure caption="[Figure 3] Time-Slicing Timeline" src="images/time-slicing-timeline.png" width="1100px" >}}

[Figure 3] shows the operation of the Time-slicing technique in a timeline format. You can see that SMs (Streaming Multiprocessors) execute kernels from CUDA apps sequentially through the GPU Context Switch process. Unlike CPU context switching, GPU context switching is an expensive operation. Due to numerous registers and shared memory in the GPU, the GPU context size is typically several MB. Therefore, the biggest disadvantage of Time-slicing is that GPU context switching occurs, causing performance degradation.

To minimize GPU context switching, the GPU performs GPU scheduling in a **non-preemptive** manner. That is, it operates so that no other kernel runs until all submitted kernels are processed. [Figure 3] also shows that no other kernel runs until all kernels submitted by a CUDA app are processed. Additionally, GPU memory is maintained until the CUDA app terminates, regardless of context switching.

### 1.2. MPS (Multi Process Service)

**MPS (Multi Process Service)** is a technique introduced to minimize the context switching cost of the Time-slicing technique. It is a technique that allows multiple CUDA apps to share a GPU through **spatial division** rather than time division. MPS Architecture is divided into before and after Volta Architecture. Additionally, to use MPS, two additional components are required: **MPS Control** (`nvidia-cuda-mps-control`) and **MPS Server** (`nvidia-cuda-mps-server`). MPS Control is a component for controlling and managing the MPS Server. MPS Server manages CUDA contexts before Volta Architecture, and after Volta Architecture, it arbitrates GPU resources.

#### 1.2.1. MPS before Volta Architecture

{{< figure caption="[Figure 4] MPS before Volta Architecture" src="images/mps-before-volta-architecture.png" width="600px" >}}

[Figure 4] shows the structure of the MPS technique before Volta Architecture. MPS Control and MPS Server create and synchronize separate CUDA contexts between CUDA apps. Therefore, CUDA apps do not directly submit kernels and GPU-related settings to the GPU, but submit them to the MPS Server through MPS Control. However, data is directly transferred to the GPU via DMA. From the GPU's perspective, it is unaware of the existence of CUDA apps and considers only the MPS Server to be using the GPU. Before Volta Architecture, spatial division could not be provided for multiple CUDA apps, so this problem was solved by using the MPS Server as a proxy server.

{{< figure caption="[Figure 5] MPS before Volta Timeline" src="images/mps-before-volta-timeline.png" width="1100px" >}}

[Figure 5] shows the operation of the MPS technique before Volta Architecture in a timeline format. As it is a spatial division technique, you can see that all kernels run simultaneously. In the MPS technique before Volta Architecture, SM and memory isolation between CUDA apps was not provided. Therefore, if a specific CUDA app violates memory, it can affect other CUDA apps.

#### 1.2.2. MPS after Volta Architecture

{{< figure caption="[Figure 6] MPS after Volta Architecture" src="images/mps-after-volta-architecture.png" width="600px" >}}

[Figure 6] shows the structure of the MPS technique after Volta Architecture. After Volta Architecture, CUDA apps directly submit kernels to the GPU. Therefore, MPS Control and MPS Server no longer create and synchronize separate contexts between CUDA apps. However, before CUDA apps submit kernels to the GPU, they check with MPS Control and MPS Server whether the submission conflicts with GPU resources used by other CUDA apps. Therefore, MPS Control and MPS Server act as arbitrators to prevent GPU resource conflicts between CUDA apps.

Additionally, after Volta Architecture, functionality was added to specify the maximum SM and memory that can be used per CUDA app. This prevents CUDA apps from unexpectedly occupying SMs and memory. However, only maximum usage limits are provided, and minimum usage guarantees are not provided. Therefore, even in the MPS technique after Volta Architecture, complete resource isolation is not provided.

{{< figure caption="[Figure 7] MPS after Volta Timeline" src="images/mps-after-volta-timeline.png" width="1100px" >}}

[Figure 7] shows the operation of the MPS technique after Volta Architecture in a timeline format. It is similar to [Figure 5], but differs in that the GPU does not manage MPS contexts and manages contexts for each CUDA app individually.

#### 1.2.3. MPS Control, MPS Server Operation Process

```shell {caption="[Shell 1] Run MPS Control and MPS Server"}
# Run MPS Control
$ nvidia-cuda-mps-control -d

# Run CUDA App
$ CUDA_VISIBLE_DEVICES=0 python3 mps_worker.py &

# Check MPS Control and MPS Server
$ ps -ef | grep mps
root       21389       1  0 14:37 ?        00:00:00 nvidia-cuda-mps-control -d
root       60374   21389  0 15:00 ?        00:00:01 nvidia-cuda-mps-server
```

MPS Control is executed through a binary named `nvidia-cuda-mps-control`, and MPS Control runs and manages a maximum of one MPS Server simultaneously. MPS Server is executed through a binary named `nvidia-cuda-mps-server`. MPS Server is not created immediately when MPS Control starts, but is created by MPS Control when a CUDA app first runs. MPS Control runs and manages a maximum of one MPS Server simultaneously, and the MPS Server created by MPS Control does not terminate even when CUDA apps terminate and is reused by CUDA apps that run afterward. [Shell 1] shows the process of running MPS Control, submitting a CUDA app, and running MPS Server.

MPS Server runs independently for each Linux user. However, since MPS Control manages a maximum of one MPS Server simultaneously, different Linux users cannot run CUDA apps through MPS at the same time. If Linux User A is running a CUDA app through MPS and Linux User B tries to run a CUDA app through MPS, Linux User A's MPS Server is forcibly terminated and Linux User B's MPS Server is created.

To send commands to MPS Control, you can pipe commands in the form `echo "[command]" | nvidia-cuda-mps-control`. Various commands exist, but representative commands are as follows.

* `get_server_list` : Outputs the MPS Server list.
* `get_server_status <PID>` : Outputs the status of the MPS Server with the specified PID.
* `get_client_list <PID>` : Outputs the PID list of CUDA apps connected to the MPS Server with the specified PID.
* `quit` : Terminates MPS Control.

After Volta Architecture, the following commands for limiting maximum SM and memory usage were added.

* `set_default_active_thread_percentage <percentage>` : Sets the Default Active Thread Percentage. Here, Active Thread Percentage means the usage rate relative to the maximum SM that a CUDA app can use. It does not affect MPS Servers that are already running and only applies to newly started MPS Servers. To change the Active Thread Percentage of a running MPS Server, use the `set_active_thread_percentage <PID> <percentage>` command.
* `get_default_active_thread_percentage` : Outputs the Default Active Thread Percentage.
* `set_active_thread_percentage <PID> <percentage>` : Sets the Active Thread Percentage of the MPS Server with the specified PID.
* `get_active_thread_percentage <PID>` : Outputs the Active Thread Percentage of the MPS Server with the specified PID.
* `set_default_device_pinned_mem_limit <dev> <value>` : Sets the Default Device Pinned Memory Limit. Here, Device Pinned Memory Limit means the maximum GPU memory size that a CUDA app can use. It does not affect MPS Servers that are already running and only applies to newly started MPS Servers. To change the Device Pinned Memory Limit of a running MPS Server, use the `set_device_pinned_mem_limit <PID> <value>` command.
* `get_default_device_pinned_mem_limit <dev>` : Outputs the Default Device Pinned Memory Limit for the specified device.
* `set_device_pinned_mem_limit <PID> <value>` : Sets the Device Pinned Memory Limit of the MPS Server with the specified PID.
* `get_device_pinned_mem_limit <PID>` : Outputs the Device Pinned Memory Limit of the MPS Server with the specified PID.

```shell {caption="[Shell 2] MPS Server Files"}
$ ls -l /tmp/nvidia-mps/
total 5
srw-rw-rw-.  1 root root   0 Feb 17 14:37 control
-rw-rw-rw-.  1 root root   0 Feb 17 14:37 control_lock
srwxr-xr-x.  1 root root   0 Feb 17 14:37 control_privileged
prwxrwxrwx.  1 root root   0 Feb 17 15:04 log
-rw-rw-rw-.  1 root root   5 Feb 17 14:37 nvidia-cuda-mps-control.pid

$ lsof +c 0 /tmp/nvidia-mps/*
COMMAND           PID USER   FD   TYPE             DEVICE SIZE/OFF  NODE NAME
nvidia-cuda-mps 17861 root   20wW  REG               0,32        0  4523 /tmp/nvidia-mps/control_lock
nvidia-cuda-mps 17861 root   26u  FIFO               0,32      0t0  4524 /tmp/nvidia-mps/log
nvidia-cuda-mps 17861 root   27w  FIFO               0,32      0t0  4524 /tmp/nvidia-mps/log
nvidia-cuda-mps 17861 root   28u  unix 0x0000000045d7a7b6      0t0 32191 /tmp/nvidia-mps/control_privileged type=SEQPACKET (LISTEN)
nvidia-cuda-mps 17861 root   29u  unix 0x00000000cec7e4ac      0t0 32192 /tmp/nvidia-mps/control type=SEQPACKET (LISTEN)
nvidia-cuda-mps 17861              0,32        0  4523 /tmp/nvidia-mps/control_lockroot   31u  unix 0x00000000a4b1b4c4      0t0 19294 /tmp/nvidia-mps/control type=SEQPACKET (CONNECTED)
nvidia-cuda-mps 21810 root    3w  FIFO               0,32      0t0  4524 /tmp/nvidia-mps/log
nvidia-cuda-mps 21810 root   20w   REG  

$ ps -fp 17861 21810
UID          PID    PPID  C STIME TTY      STAT   TIME CMD
root       17861       1  0 02:47 ?        Ssl    0:00 nvidia-cuda-mps-control -d
root       21810   17861  0 02:56 ?        Sl     0:01 nvidia-cuda-mps-server
```

[Shell 2] shows the list of files created when MPS Control and MPS Server are running. The file path can be configured through the `CUDA_MPS_PIPE_DIRECTORY` environment variable, and the default path is `/tmp/nvidia-mps/`. The roles of each file are as follows.

* `control` : Unix Domain Socket for general users. Commands like `echo "get_server_list" | nvidia-cuda-mps-control` are sent through this socket.
* `control_lock` : Lock file for concurrency control when accessing the `control` socket.
* `control_privileged` : Unix Domain Socket exclusively for root/privileged users. Administrative commands like `set_default_active_thread_percentage` are processed through this socket.
* `log` : Named pipe for MPS Server log output. Output logs are received by MPS Control and stored in the path set by the `CUDA_MPS_LOG_DIRECTORY` environment variable. The default path is `/var/log/nvidia-mps/`.
* `nvidia-cuda-mps-control.pid` : Regular file storing the PID of the MPS control daemon. Used for preventing duplicate execution and process management.

The CUDA SDK checks by default whether the `control` Unix Domain Socket exists in the path specified by the `CUDA_MPS_PIPE_DIRECTORY` environment variable or the default path `/tmp/nvidia-mps/`, and if found, runs CUDA apps using MPS. Therefore, if MPS is running, CUDA apps operate using MPS by default.

### 1.3. MIG (Multi Instance GPU)

**MIG (Multi Instance GPU)** is a hardware-level GPU isolation and virtualization technique provided by the GPU. The MIG technique completely isolates the GPU's SM and memory to create vGPUs (Virtual GPUs) and provides them for use by CUDA apps. When MIG is enabled, the Linux kernel recognizes multiple GPU instances rather than a single GPU. It is similar to the hardware-level virtualization technique SR-IOV (Single Root I/O Virtualization). Since it is a hardware-level virtualization technique, it is only available on GPUs after Ampere Architecture.

{{< figure caption="[Figure 8] MIG Architecture" src="images/mig-architecture.png" width="600px" >}}

[Figure 8] shows the structure of the MIG technique. In MIG, GPUs are virtualized in two units: **GPU Instance** and **Compute Instance**. GPU Instance performs the role of isolating GPU memory. Compute Instance performs the role of isolating SMs within a GPU Instance. Therefore, GPU Instance and Compute Instance are generally configured in a 1:1 ratio, but 1:N configuration is also possible. In a 1:N configuration, Compute Instances share and use the memory of the GPU Instance. CUDA apps consider Compute Instances as vGPUs.

[Figure 8] shows an example where the vGPU used by CUDA App A is configured with GPU Instance and Compute Instance in a 1:1 ratio to use a completely isolated vGPU. It also shows an example where the vGPUs of App B and App C are configured with GPU Instance and Compute Instance in a 1:N ratio to share and use the GPU Instance's memory.

{{< figure caption="[Figure 9] MIG A100 MIG GPU Instance Profile" src="images/mig-a100-profile.png" width="900px" >}}

The MIG technique provides complete isolation between vGPUs, but the SM and memory sizes allocated to vGPUs cannot be freely set and can only be allocated in limited sizes according to profiles. [Figure 9] shows the MIG GPU Instance Profile of an A100 GPU with 40GB capacity. Profile names are defined in the form `[X]g.[XX]gb`, where `[X]g` means the maximum number of SM slices that can be allocated to a GPU Instance, and `[XX]gb` means the maximum memory size that can be allocated to a GPU Instance.

For example, the `4g.20gb` profile means a profile that can use 4 SM slices and is configured with 20GB of memory allocated. For A100 GPUs, there are 5 profiles: `7g.40gb`, `4g.20gb`, `3g.20gb`, `2g.10gb`, and `1g.5gb`, and profile configuration is only possible with the combinations in [Figure 9]. The MIG technique provides high isolation but has the disadvantage of making it difficult to optimize the usage rate of each vGPU due to limited profile configurations. It also has the disadvantage of making it difficult to increase the overall GPU usage rate due to high isolation. While Time-slicing and MPS techniques allow specific CUDA apps to utilize the entire GPU when needed, the MIG technique only provides isolation functionality and does not provide over-committing functionality.

{{< figure caption="[Figure 10] MIG Timeline" src="images/mig-timeline.png" width="1100px" >}}

[Figure 10] shows the operation of the MIG technique in a timeline format. Memory is isolated at the GPU Instance level, and SMs are isolated at the Compute Instance level, and you can see that multiple kernels run simultaneously, similar to the MPS technique.

#### 1.3.1. MIG Configuration Method

```shell {caption="[Shell 3] Enable MIG and Check GPU Instance Profile"}
# Enable MIG for GPU 0
$ nvidia-smi -i 0 -mig 1

# Check MIG mode for GPU 0
$ nvidia-smi -i 0 --query-gpu=mig.mode.current --format=csv,noheader
Enabled

# Check MIG GPU instance profiles for GPU 0
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
|| GPU instance profiles:                                                        |
|| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
||                                Free/Total   GiB              CE    JPEG  OFA  |
||===============================================================================|
||   0  MIG 1g.5gb          19     7/7        4.75       No     14     0     0   |
||                                                               1     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
||                                                               1     1     1   |
+-------------------------------------------------------------------------------+
||   0  MIG 1g.10gb         15     4/4        9.75       No     14     1     0   |
||                                                               1     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 2g.10gb         14     3/3        9.75       No     28     1     0   |
||                                                               2     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 3g.20gb          9     2/2        19.62      No     42     2     0   |
||                                                               3     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 4g.20gb          5     1/1        19.62      No     56     2     0   |
||                                                               4     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 7g.40gb          0     1/1        39.38      No     98     5     0   |
||                                                               7     1     1   |
+-------------------------------------------------------------------------------+
```

[Shell 3] shows the process of enabling MIG and checking GPU Instance profiles. All processes can be performed through the `nvidia-smi` command. The `-i` option specifies a particular GPU by number. The `-mig 1` option enables MIG. If multiple GPUs exist, MIG must be enabled for each GPU.

```shell {caption="[Shell 4] Create MIG GPU Instance"}
# Create GPU instance with profile 4g.20gb
$ nvidia-smi mig -i 0 -cgi 4g.20gb
Successfully created GPU instance ID  2 on GPU  0 using profile MIG 4g.20gb (ID  5)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
|| GPU instance profiles:                                                        |
|| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
||                                Free/Total   GiB              CE    JPEG  OFA  |
||===============================================================================|
||   0  MIG 1g.5gb          19     3/7        4.75       No     14     0     0   |
||                                                               1     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
||                                                               1     1     1   |
+-------------------------------------------------------------------------------+
||   0  MIG 1g.10gb         15     2/4        9.75       No     14     1     0   |
||                                                               1     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 2g.10gb         14     1/3        9.75       No     28     1     0   |
||                                                               2     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 3g.20gb          9     1/2        19.62      No     42     2     0   |
||                                                               3     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
||                                                               4     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
||                                                               7     1     1   |
+-------------------------------------------------------------------------------+

# Create GPU instance with profile 2g.10gb
$ nvidia-smi mig -i 0 -cgi 2g.10gb
Successfully created GPU instance ID  3 on GPU  0 using profile MIG 2g.10gb (ID 14)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
|| GPU instance profiles:                                                        |
|| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
||                                Free/Total   GiB              CE    JPEG  OFA  |
||===============================================================================|
||   0  MIG 1g.5gb          19     1/7        4.75       No     14     0     0   |
||                                                               1     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
||                                                               1     1     1   |
+-------------------------------------------------------------------------------+
||   0  MIG 1g.10gb         15     1/4        9.75       No     14     1     0   |
||                                                               1     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 2g.10gb         14     0/3        9.75       No     28     1     0   |
||                                                               2     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 3g.20gb          9     0/2        19.62      No     42     2     0   |
||                                                               3     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
||                                                               4     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
||                                                               7     1     1   |
+-------------------------------------------------------------------------------+

# Create GPU instance with profile 1g.5gb
$ nvidia-smi mig -i 0 -cgi 1g.5gb
Successfully created GPU instance ID  9 on GPU  0 using profile MIG 1g.5gb (ID 19)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
|| GPU instance profiles:                                                        |
|| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
||                                Free/Total   GiB              CE    JPEG  OFA  |
||===============================================================================|
||   0  MIG 1g.5gb          19     0/7        4.75       No     14     0     0   |
||                                                               1     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 1g.5gb+me       20     0/1        4.75       No     14     1     0   |
||                                                               1     1     1   |
+-------------------------------------------------------------------------------+
||   0  MIG 1g.10gb         15     0/4        9.75       No     14     1     0   |
||                                                               1     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 2g.10gb         14     0/3        9.75       No     28     1     0   |
||                                                               2     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 3g.20gb          9     0/2        19.62      No     42     2     0   |
||                                                               3     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
||                                                               4     0     0   |
+-------------------------------------------------------------------------------+
||   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
||                                                               7     1     1   |
+-------------------------------------------------------------------------------+

# Check MIG GPU instances
$ nvidia-smi mig -i 0 -lgi
+---------------------------------------------------------+
|| GPU instances:                                          |
|| GPU   Name               Profile  Instance   Placement  |
||                            ID       ID       Start:Size |
||=========================================================|
||   0  MIG 1g.5gb            19        9          6:1     |
+---------------------------------------------------------+
||   0  MIG 2g.10gb           14        3          4:2     |
+---------------------------------------------------------+
||   0  MIG 4g.20gb            5        2          0:4     |
+---------------------------------------------------------+
```

[Shell 4] shows the process of creating and checking MIG GPU Instances. You can see that three GPU Instances were created using the `4g.20gb`, `2g.10gb`, and `1g.5gb` profiles one by one. This matches the second profile combination in [Figure 9]. You can also see that GPU Instance IDs were created sequentially as `2`, `3`, and `9`. GPU Instance IDs are used when creating Compute Instances.

```shell {caption="[Shell 5] Create MIG Compute Instance"}
# Check and create a compute instance profile for GPU instance ID 2 (4g.20gb GPU Instance)
$ nvidia-smi mig -i 0 -gi 2 -lcip
+--------------------------------------------------------------------------------------+
|| Compute instance profiles:                                                           |
|| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
||       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
||         ID                                                          CE    JPEG       |
||======================================================================================|
||   0      2       MIG 1c.4g.20gb       0      4/4           14        2     0     0   |
||                                                                      4     0         |
+--------------------------------------------------------------------------------------+
||   0      2       MIG 2c.4g.20gb       1      2/2           28        2     0     0   |
||                                                                      4     0         |
+--------------------------------------------------------------------------------------+
||   0      2       MIG 4g.20gb          3*     1/1           56        2     0     0   |
||                                                                      4     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 2 -cci 4g.20gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  2 using profile MIG 4g.20gb (ID  3)
$ nvidia-smi mig -i 0 -gi 2 -lcip
+--------------------------------------------------------------------------------------+
|| Compute instance profiles:                                                           |
|| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
||       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
||         ID                                                          CE    JPEG       |
||======================================================================================|
||   0      2       MIG 1c.4g.20gb       0      0/4           14        2     0     0   |
||                                                                      4     0         |
+--------------------------------------------------------------------------------------+
||   0      2       MIG 2c.4g.20gb       1      0/2           28        2     0     0   |
||                                                                      4     0         |
+--------------------------------------------------------------------------------------+
||   0      2       MIG 4g.20gb          3*     0/1           56        2     0     0   |
||                                                                      4     0         |
+--------------------------------------------------------------------------------------+

# Check and create two compute instance profiles for GPU instance ID 3 (2g.10gb GPU Instance)
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
|| Compute instance profiles:                                                           |
|| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
||       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
||         ID                                                          CE    JPEG       |
||======================================================================================|
||   0      3       MIG 1c.2g.10gb       0      2/2           14        1     0     0   |
||                                                                      2     0         |
+--------------------------------------------------------------------------------------+
||   0      3       MIG 2g.10gb          1*     1/1           28        1     0     0   |
||                                                                      2     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 3 -cci 1c.2g.10gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  3 using profile MIG 1c.2g.10gb (ID  0)
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
|| Compute instance profiles:                                                           |
|| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
||       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
||         ID                                                          CE    JPEG       |
||======================================================================================|
||   0      3       MIG 1c.2g.10gb       0      1/2           14        1     0     0   |
||                                                                      2     0         |
+--------------------------------------------------------------------------------------+
||   0      3       MIG 2g.10gb          1*     0/1           28        1     0     0   |
||                                                                      2     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 3 -cci 1c.2g.10gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  3 using profile MIG 1c.2g.10gb (ID  0)
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
|| Compute instance profiles:                                                           |
|| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
||       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
||         ID                                                          CE    JPEG       |
||======================================================================================|
||   0      3       MIG 1c.2g.10gb       0      0/2           14        1     0     0   |
||                                                                      2     0         |
+--------------------------------------------------------------------------------------+
||   0      3       MIG 2g.10gb          1*     0/1           28        1     0     0   |
||                                                                      2     0         |
+--------------------------------------------------------------------------------------+

# Check and create a compute instance profile for GPU instance ID 9 (1g.5gb GPU Instance)
$ nvidia-smi mig -i 0 -gi 9 -lcip
+--------------------------------------------------------------------------------------+
|| Compute instance profiles:                                                           |
|| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
||       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
||         ID                                                          CE    JPEG       |
||======================================================================================|
||   0      9       MIG 1g.5gb           0*     1/1           14        0     0     0   |
||                                                                      1     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 9 -cci 1g.5gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  9 using profile MIG 1g.5gb (ID  0)
$ nvidia-smi mig -i 0 -gi 9 -lcip
+--------------------------------------------------------------------------------------+
|| Compute instance profiles:                                                           |
|| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
||       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
||         ID                                                          CE    JPEG       |
||======================================================================================|
||   0      9       MIG 1g.5gb           0*     0/1           14        0     0     0   |
||                                                                      1     0         |
+--------------------------------------------------------------------------------------+

# Check GPU instances and Compute instances
$ nvidia-smi mig -i 0 -lgi
+---------------------------------------------------------+
|| GPU instances:                                          |
|| GPU   Name               Profile  Instance   Placement  |
||                            ID       ID       Start:Size |
||=========================================================|
||   0  MIG 1g.5gb            19        9          6:1     |
+---------------------------------------------------------+
||   0  MIG 2g.10gb           14        3          4:2     |
+---------------------------------------------------------+
||   0  MIG 4g.20gb            5        2          0:4     |
+---------------------------------------------------------+

$ nvidia-smi mig -i 0 -lci
+--------------------------------------------------------------------+
|| Compute instances:                                                 |
|| GPU     GPU       Name             Profile   Instance   Placement  |
||       Instance                       ID        ID       Start:Size |
||         ID                                                         |
||====================================================================|
||   0      9       MIG 1g.5gb           0         0          0:1     |
+--------------------------------------------------------------------+
||   0      3       MIG 1c.2g.10gb       0         0          0:1     |
+--------------------------------------------------------------------+
||   0      3       MIG 1c.2g.10gb       0         1          1:1     |
+--------------------------------------------------------------------+
||   0      2       MIG 4g.20gb          3         0          0:4     |
+--------------------------------------------------------------------+
```

[Shell 5] shows the process of creating and checking Compute Instances. After a GPU Instance is created, you can check the Compute Instance profiles that can be created for that GPU Instance. For the `4g.20gb` GPU Instance, there are 3 profiles: `1c.4g.20gb`, `2c.4g.20gb`, and `4g.20gb`. For the `2g.10gb` GPU Instance, there are 2 profiles: `1c.2g.10gb` and `2g.10gb`. For the `1g.5gb` GPU Instance, there is 1 profile: `1g.5gb`.

You can see that one Compute Instance was created using the `4g.20gb` profile for the `4g.20gb` GPU Instance, two Compute Instances were created using the `1c.2g.10gb` profile for the `2g.10gb` GPU Instance, and one Compute Instance was created using the `1g.5gb` profile for the `1g.5gb` GPU Instance.

```shell {caption="[Shell 6] Check MIG vGPU"}
$ nvidia-smi -i 0
Tue Feb 17 16:58:38 2026
+-----------------------------------------------------------------------------------------+
|| NVIDIA-SMI 580.126.09             Driver Version: 580.126.09     CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
|| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
|| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
||                                         |                        |               MIG M. |
||=========================================+========================+======================|
||   0  NVIDIA A100-SXM4-40GB          On  |   00000000:10:1C.0 Off |                   On |
|| N/A   40C    P0             43W /  400W |     249MiB /  40960MiB |     N/A      Default |
||                                         |                        |              Enabled |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
|| MIG devices:                                                                            |
+------------------+----------------------------------+-----------+-----------------------+
|| GPU  GI  CI  MIG |              Shared Memory-Usage |        Vol|        Shared         |
||      ID  ID  Dev |                Shared BAR1-Usage | SM     Unc| CE ENC  DEC  OFA  JPG |
||                  |                                  |        ECC|                       |
||==================+==================================+===========+=======================|
||  0    2   0   0  |             142MiB / 20096MiB    | 56      0 |  4   0    2    0    0 |
||                  |               0MiB / 12211MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
||  0    3   0   1  |              71MiB /  9984MiB    | 14      0 |  2   0    1    0    0 |
||                  |               0MiB /  6105MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
||  0    3   1   2  |              71MiB /  9984MiB    | 14      0 |  2   0    1    0    0 |
||                  |               0MiB /  6105MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
||  0    9   0   3  |              36MiB /  4864MiB    | 14      0 |  1   0    0    0    0 |
||                  |               0MiB /  3052MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------------------+
|| Processes:                                                                              |
||  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
||        ID   ID                                                               Usage      |
||=========================================================================================|
||  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+

$ nvidia-smi -i 0 -L
GPU 0: NVIDIA A100-SXM4-40GB (UUID: GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9)
  MIG 4g.20gb     Device  0: (UUID: MIG-c42101f0-a1fa-5b68-8908-7c5c887f28bd)
  MIG 1c.2g.10gb  Device  1: (UUID: MIG-8970491e-16e0-5140-9f8f-d561baa3c186)
  MIG 1c.2g.10gb  Device  2: (UUID: MIG-239565ce-30e3-52d7-8197-5630d3ce21fa)
  MIG 1g.5gb      Device  3: (UUID: MIG-20301a31-77fa-59ec-b0b8-7ef543821f29)
```

[Shell 6] shows the process of checking MIG vGPUs. You can check MIG vGPU information by querying the GPU through the `nvidia-smi` command. You can also check the vGPU UUID through the `-L` command. UUIDs are used to determine which vGPU CUDA apps will use.

```shell {caption="[Shell 7] Check MIG vGPU Device Files"}
# Check MIG device files
$ ls -l /dev/nvidia-caps/
cr--------.  1 root root 242,  0 Feb 17 16:23 nvidia-cap0
cr--------.  1 root root 242,  1 Feb 17 16:23 nvidia-cap1
cr--r--r--.  1 root root 242,  2 Feb 17 16:23 nvidia-cap2
cr--r--r--.  1 root root 242, 21 Feb 17 16:24 nvidia-cap21
cr--r--r--.  1 root root 242, 22 Feb 17 16:32 nvidia-cap22
cr--r--r--.  1 root root 242, 30 Feb 17 16:25 nvidia-cap30
cr--r--r--.  1 root root 242, 31 Feb 17 16:45 nvidia-cap31
cr--r--r--.  1 root root 242, 32 Feb 17 16:45 nvidia-cap32
cr--r--r--.  1 root root 242, 84 Feb 17 16:26 nvidia-cap84
cr--r--r--.  1 root root 242, 85 Feb 17 16:54 nvidia-cap85

# Check what cap is what GI/CI
find /proc/driver/nvidia/capabilities/gpu0/mig/ -name access | sort | while read f; do
    minor=$(grep DeviceFileMinor "$f" | awk '{print $2}')
    echo "$f  →  /dev/nvidia-caps/nvidia-cap${minor}"
done
/proc/driver/nvidia/capabilities/gpu0/mig/gi2/access  →  /dev/nvidia-caps/nvidia-cap21
/proc/driver/nvidia/capabilities/gpu0/mig/gi2/ci0/access  →  /dev/nvidia-caps/nvidia-cap22
/proc/driver/nvidia/capabilities/gpu0/mig/gi3/access  →  /dev/nvidia-caps/nvidia-cap30
/proc/driver/nvidia/capabilities/gpu0/mig/gi3/ci0/access  →  /dev/nvidia-caps/nvidia-cap31
/proc/driver/nvidia/capabilities/gpu0/mig/gi3/ci1/access  →  /dev/nvidia-caps/nvidia-cap32
/proc/driver/nvidia/capabilities/gpu0/mig/gi9/access  →  /dev/nvidia-caps/nvidia-cap84
/proc/driver/nvidia/capabilities/gpu0/mig/gi9/ci0/access  →  /dev/nvidia-caps/nvidia-cap85
```

Device files are created for each GPU Instance and Compute Instance in the form `/dev/nvidia-caps/nvidia-cap[Minor Number]`. [Shell 7] shows the process of checking device files for GPU Instances and Compute Instances, and you can see which device file maps to which GPU Instance or Compute Instance.

#### 1.3.2. How to Use MIG vGPU

```shell {caption="[Shell 8] How to Use MIG vGPU"}
# Run with MIG UUID
CUDA_VISIBLE_DEVICES=MIG-c42101f0-a1fa-5b68-8908-7c5c887f28bd   # 4g.20gb
CUDA_VISIBLE_DEVICES=MIG-8970491e-16e0-5140-9f8f-d561baa3c186   # 1c.2g.10gb first
CUDA_VISIBLE_DEVICES=MIG-239565ce-30e3-52d7-8197-5630d3ce21fa   # 1c.2g.10gb second
CUDA_VISIBLE_DEVICES=MIG-20301a31-77fa-59ec-b0b8-7ef543821f29   # 1g.5gb

# Run with MIG-GPU-<gpu-uuid>/<gi-id>/<ci-id>
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/2/0   # 4g.20gb
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/3/0   # 1c.2g.10gb first
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/3/1   # 1c.2g.10gb second
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/9/0   # 1g.5gb
```

[Shell 8] shows how to use MIG vGPU in CUDA apps. The CUDA SDK can specify which GPUs CUDA apps can use through the `CUDA_VISIBLE_DEVICES` environment variable, so you can similarly specify MIG vGPU in the `CUDA_VISIBLE_DEVICES` environment variable to allow CUDA apps to use MIG vGPU. There are two ways to specify MIG vGPU in the `CUDA_VISIBLE_DEVICES` environment variable: by specifying the MIG vGPU UUID or by specifying it in the form `MIG-GPU-<gpu-uuid>/<gi-id>/<ci-id>`. To use multiple MIG vGPUs, you can specify multiple MIG vGPUs using `,` as a separator.

#### 1.3.3. with Time-slicing and MPS

{{< figure caption="[Figure 11] MIG with Time-slicing and MPS Architecture" src="images/mig-time-slicing-mps-architecture.png" width="800px" >}} 

It is possible to apply Time-slicing or MPS techniques again to vGPUs created through the MIG technique to share vGPUs. [Figure 11] shows a structure where Time-slicing is applied to vGPUs created through the MIG technique to share vGPUs. Time-slicing is applied to the first vGPU to share it, and MPS is applied to the second vGPU to share it.

## 2. References

* Time-Slicing, MPS, MIG: [https://stackoverflow.com/questions/78653544/why-use-mps-time-slicing-or-mig-if-nvidias-defaults-have-better-performance](https://stackoverflow.com/questions/78653544/why-use-mps-time-slicing-or-mig-if-nvidias-defaults-have-better-performance)
* NVIDIA GPU Sharing: [https://www.youtube.com/watch?v=IA6u8Jgox5M](https://www.youtube.com/watch?v=IA6u8Jgox5M)
* NVIDIA GPU Sharing: [https://aws.amazon.com/blogs/containers/gpu-sharing-on-amazon-eks-with-nvidia-time-slicing-and-accelerated-ec2-instances/](https://aws.amazon.com/blogs/containers/gpu-sharing-on-amazon-eks-with-nvidia-time-slicing-and-accelerated-ec2-instances/)
* NVIDIA GPU Sharing Benchmark : [https://www.youtube.com/watch?v=nOgxv_R13Dg](https://www.youtube.com/watch?v=nOgxv_R13Dg)
* NVIDIA MPS : [https://docs.nvidia.com/deploy/mps/index.html](https://docs.nvidia.com/deploy/mps/index.html)
* NVIDIA MPS : [https://comsys-pim.tistory.com/10](https://comsys-pim.tistory.com/10)
* NVIDIA MPS : [https://www.databricks.com/kr/blog/scaling-small-llms-nvidia-mps](https://www.databricks.com/kr/blog/scaling-small-llms-nvidia-mps)
* NVIDIA MIG : [https://toss.tech/article/toss-securities-gpu-mig](https://toss.tech/article/toss-securities-gpu-mig)
* NVIDAA MIG Guide : [https://docs.nvidia.com/datacenter/tesla/pdf/MIG_User_Guide.pdf](https://docs.nvidia.com/datacenter/tesla/pdf/MIG_User_Guide.pdf)
* NVIDAA MIG A100 : [https://roychou121.github.io/2020/10/29/nvidia-A100-MIG/](https://roychou121.github.io/2020/10/29/nvidia-A100-MIG/)
