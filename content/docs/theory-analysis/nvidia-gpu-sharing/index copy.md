---
title: NVIDIA GPU Sharing
draft: true
---

## 1. NVIDIA GPU Sharing

{{< figure caption="[Figure 1] Example Applications" src="images/example-apps.png" width="900px" >}}

GPU Sharing 기법은 다수의 Process가 하나의 GPU를 공유하여 사용하는 기법을 의미한다. 크게 **Time-Slicing**, **MPS**, **MIG** 3가지 기법이 존재한다. [Figure 1]은 GPU Sharing 기법을 살펴보기 위한 예제 Application들을 나타내고 있다.

### 1.1. Time-Slicing

{{< figure caption="[Figure 2] Time-Slicing Architecture" src="images/time-slicing-architecture.png" width="600px" >}}

{{< figure caption="[Figure 3] Time-Slicing Timeline" src="images/time-slicing-timeline.png" width="1100px" >}}

### 1.2. MPS (Multi Process Service)

{{< figure caption="[Figure 4] MPS before Volta Architecture" src="images/mps-before-volta-architecture.png" width="600px" >}}

{{< figure caption="[Figure 5] MPS before Volta Timeline" src="images/mps-before-volta-timeline.png" width="1100px" >}}

{{< figure caption="[Figure 6] MPS after Volta Architecture" src="images/mps-after-volta-architecture.png" width="600px" >}}

{{< figure caption="[Figure 7] MPS after Volta Timeline" src="images/mps-after-volta-timeline.png" width="1100px" >}}

```
$ nvidia-cuda-mps-control -d

$ ps -ef | grep mps
root       21389       1  0 14:37 ?        00:00:00 nvidia-cuda-mps-control -d
root       60374   21389  0 15:00 ?        00:00:01 nvidia-cuda-mps-server
```

```python
import torch, time, os

dev = torch.device("cuda:0")
a = torch.randn(4096, 4096, device=dev)
b = torch.randn(4096, 4096, device=dev)

torch.cuda.synchronize()
t0 = time.time()

for _ in range(50):
    c = torch.mm(a, b)

torch.cuda.synchronize()
print(f"GPU {os.environ.get('CUDA_VISIBLE_DEVICES','?')} | PID {os.getpid()} | {time.time()-t0:.3f}s")
```

```shell
python3 -m ensurepip --upgrade
pip3 install torch --index-url https://download.pytorch.org/whl/cu124
pip3 install numpy

CUDA_VISIBLE_DEVICES=0 python3 mps_worker.py &
CUDA_VISIBLE_DEVICES=0 python3 mps_worker.py &
CUDA_VISIBLE_DEVICES=1 python3 mps_worker.py &
CUDA_VISIBLE_DEVICES=1 python3 mps_worker.py &
wait

GPU 1 | PID 64216 | 1.120s
GPU 0 | PID 64214 | 1.128s
GPU 0 | PID 64213 | 1.126s
GPU 1 | PID 64215 | 1.132s

# 기존 데몬 종료
echo quit | nvidia-cuda-mps-control

# GPU별 데몬 시작
for i in 0 1 2 3; do
    CUDA_VISIBLE_DEVICES=$i \
    CUDA_MPS_PIPE_DIRECTORY=/tmp/mps_$i \
    CUDA_MPS_LOG_DIRECTORY=/tmp/mps_log_$i \
    nvidia-cuda-mps-control -d
done

CUDA_VISIBLE_DEVICES=0 CUDA_MPS_PIPE_DIRECTORY=/tmp/mps_0 python3 mps_worker.py &
CUDA_VISIBLE_DEVICES=0 CUDA_MPS_PIPE_DIRECTORY=/tmp/mps_0 python3 mps_worker.py &
CUDA_VISIBLE_DEVICES=1 CUDA_MPS_PIPE_DIRECTORY=/tmp/mps_1 python3 mps_worker.py &
CUDA_VISIBLE_DEVICES=1 CUDA_MPS_PIPE_DIRECTORY=/tmp/mps_1 python3 mps_worker.py &
wait

ls -la /tmp/nvidia-mps/
total 4
drwxrwxrwx.  2 root root 140 Feb 17 14:37 .
drwxrwxrwt. 14 root root 300 Feb 17 15:09 ..
srw-rw-rw-.  1 root root   0 Feb 17 14:37 control
-rw-rw-rw-.  1 root root   0 Feb 17 14:37 control_lock
srwxr-xr-x.  1 root root   0 Feb 17 14:37 control_privileged
prwxrwxrwx.  1 root root   0 Feb 17 15:04 log
-rw-rw-rw-.  1 root root   5 Feb 17 14:37 nvidia-cuda-mps-control.pid
```

control Unix / 소켓 / 일반 사용자용 제어 소켓. echo "get_server_list" | nvidia-cuda-mps-control 같은 명령이 이 소켓을 통해 전달됨
control_lock / 일반 파일 /control 소켓 접근 시 동시성 제어를 위한 락 파일
control_privileged / Unix 소켓 / root/특권 사용자 전용 제어 소켓. set_default_active_thread_percentage 같은 관리 명령은 이 소켓을 통해 처리됨
logNamed / pipe (FIFO) / MPS 서버의 로그 출력 파이프. cat /tmp/nvidia-mps/log으로 실시간 로그 확인 가능
nvidia-cuda-mps-control.pid / 일반 파일 / MPS control daemon의 PID가 저장된 파일. 중복 실행 방지 및 프로세스 관리에 사용됨

핵심 이유는 GPU별 독립적인 자원 제어입니다.
1. Active Thread Percentage 제어
MPS는 프로세스가 GPU SM을 얼마나 쓸 수 있는지 제한할 수 있는데, 이 설정이 데몬 단위로 적용됩니다.
bash# GPU 0: 클라이언트당 50%로 제한
CUDA_MPS_PIPE_DIRECTORY=/tmp/mps_0 \
echo "set_default_active_thread_percentage 50" | nvidia-cuda-mps-control

# GPU 1: 클라이언트당 30%로 제한
CUDA_MPS_PIPE_DIRECTORY=/tmp/mps_1 \
echo "set_default_active_thread_percentage 30" | nvidia-cuda-mps-control
단일 데몬이면 이 설정이 모든 GPU에 동일하게 적용되어서 GPU마다 다른 비율을 줄 수 없습니다.
2. 장애 격리
단일 데몬에서 한 클라이언트가 치명적 에러(GPU fault)를 내면, 같은 데몬 아래의 모든 GPU 클라이언트가 영향을 받을 수 있습니다. GPU별로 분리하면 해당 GPU의 클라이언트만 영향받습니다.
3. 독립적 시작/종료
특정 GPU의 MPS만 재시작하거나 종료할 수 있습니다. 단일 데몬이면 전체를 내렸다 올려야 합니다.
결론적으로, 모든 GPU를 동일 조건으로 쓰고 장애 격리가 크게 중요하지 않은 환경이면 단일 데몬으로 충분하고, 멀티테넌트나 프로덕션 환경에서 GPU별 QoS가 필요하면 분리하는 게 좋습니다.

### 1.3. MIG (Multi Instance GPU)

{{< figure caption="[Figure 8] MIG Architecture" src="images/mig-architecture.png" width="600px" >}}

{{< figure caption="[Figure 9] MIG A100 MIG Profile" src="images/mig-a100-profile.png" width="900px" >}}

{{< figure caption="[Figure 10] MIG Timeline" src="images/mig-timeline.png" width="1100px" >}}

```shell
# 1) 서비스 자동시작 비활성화
sudo systemctl disable nvidia-fabricmanager
sudo systemctl disable nvidia-persistenced
sudo systemctl stop nvidia-fabricmanager
sudo systemctl stop nvidia-persistenced

# 2) nvidia 커널 모듈 강제 언로드
sudo rmmod nvidia_uvm
sudo rmmod nvidia_drm
sudo rmmod nvidia_modeset
sudo rmmod nvidia

# 3) 모듈 다시 로드 → MIG 활성화
sudo modprobe nvidia
sudo nvidia-smi -i 0 -mig 1
reboot now

# 4) 서비스 재시작
sudo systemctl start nvidia-persistenced
sudo systemctl start nvidia-fabricmanager

# 5) 확인
nvidia-smi -i 0 --query-gpu=mig.mode.current --format=csv,noheader

###
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
| GPU instance profiles:                                                        |
| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                                Free/Total   GiB              CE    JPEG  OFA  |
|===============================================================================|
|   0  MIG 1g.5gb          19     7/7        4.75       No     14     0     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
|                                                               1     1     1   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.10gb         15     4/4        9.75       No     14     1     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 2g.10gb         14     3/3        9.75       No     28     1     0   |
|                                                               2     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 3g.20gb          9     2/2        19.62      No     42     2     0   |
|                                                               3     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 4g.20gb          5     1/1        19.62      No     56     2     0   |
|                                                               4     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 7g.40gb          0     1/1        39.38      No     98     5     0   |
|                                                               7     1     1   |
+-------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -cgi 4g.20gb
Successfully created GPU instance ID  1 on GPU  0 using profile MIG 4g.20gb (ID  5)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
| GPU instance profiles:                                                        |
| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                                Free/Total   GiB              CE    JPEG  OFA  |
|===============================================================================|
|   0  MIG 1g.5gb          19     3/7        4.75       No     14     0     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
|                                                               1     1     1   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.10gb         15     2/4        9.75       No     14     1     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 2g.10gb         14     1/3        9.75       No     28     1     0   |
|                                                               2     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 3g.20gb          9     1/2        19.62      No     42     2     0   |
|                                                               3     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
|                                                               4     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
|                                                               7     1     1   |
+-------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -cgi 2g.10gb
Successfully created GPU instance ID  3 on GPU  0 using profile MIG 2g.10gb (ID 14)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
| GPU instance profiles:                                                        |
| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                                Free/Total   GiB              CE    JPEG  OFA  |
|===============================================================================|
|   0  MIG 1g.5gb          19     1/7        4.75       No     14     0     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
|                                                               1     1     1   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.10gb         15     1/4        9.75       No     14     1     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 2g.10gb         14     0/3        9.75       No     28     1     0   |
|                                                               2     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 3g.20gb          9     0/2        19.62      No     42     2     0   |
|                                                               3     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
|                                                               4     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
|                                                               7     1     1   |
+-------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -cgi 1g.5gb
Successfully created GPU instance ID  9 on GPU  0 using profile MIG 1g.5gb (ID 19)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
| GPU instance profiles:                                                        |
| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                                Free/Total   GiB              CE    JPEG  OFA  |
|===============================================================================|
|   0  MIG 1g.5gb          19     0/7        4.75       No     14     0     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me       20     0/1        4.75       No     14     1     0   |
|                                                               1     1     1   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.10gb         15     0/4        9.75       No     14     1     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 2g.10gb         14     0/3        9.75       No     28     1     0   |
|                                                               2     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 3g.20gb          9     0/2        19.62      No     42     2     0   |
|                                                               3     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
|                                                               4     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
|                                                               7     1     1   |
+-------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -lgi
+---------------------------------------------------------+
| GPU instances:                                          |
| GPU   Name               Profile  Instance   Placement  |
|                            ID       ID       Start:Size |
|=========================================================|
|   0  MIG 1g.5gb            19        9          6:1     |
+---------------------------------------------------------+
|   0  MIG 2g.10gb           14        3          4:2     |
+---------------------------------------------------------+
|   0  MIG 4g.20gb            5        2          0:4     |
+---------------------------------------------------------+

# 
$ nvidia-smi mig -i 0 -gi 2 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      2       MIG 1c.4g.20gb       0      4/4           14        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
|   0      2       MIG 2c.4g.20gb       1      2/2           28        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
|   0      2       MIG 4g.20gb          3*     1/1           56        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
$ nvidia-smi mig -i 0 -gi 2 -cci
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  2 using profile MIG 4g.20gb (ID  3)
$ nvidia-smi mig -i 0 -gi 2 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      2       MIG 1c.4g.20gb       0      0/4           14        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
|   0      2       MIG 2c.4g.20gb       1      0/2           28        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
|   0      2       MIG 4g.20gb          3*     0/1           56        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+

# 
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      3       MIG 1c.2g.10gb       0      2/2           14        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+
|   0      3       MIG 2g.10gb          1*     1/1           28        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 3 -cci 1c.2g.10gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  3 using profile MIG 1c.2g.10gb (ID  0)
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      3       MIG 1c.2g.10gb       0      1/2           14        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+
|   0      3       MIG 2g.10gb          1*     0/1           28        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 3 -cci 1c.2g.10gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  3 using profile MIG 1c.2g.10gb (ID  0)
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      3       MIG 1c.2g.10gb       0      0/2           14        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+
|   0      3       MIG 2g.10gb          1*     0/1           28        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+

# 
$ nvidia-smi mig -i 0 -gi 9 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      9       MIG 1g.5gb           0*     1/1           14        0     0     0   |
|                                                                      1     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 9 -cci 1g.5gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  9 using profile MIG 1g.5gb (ID  0)
$ nvidia-smi mig -i 0 -gi 9 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      9       MIG 1g.5gb           0*     0/1           14        0     0     0   |
|                                                                      1     0         |
+--------------------------------------------------------------------------------------+

# 
$ nvidia-smi mig -i 0 -lgi
+---------------------------------------------------------+
| GPU instances:                                          |
| GPU   Name               Profile  Instance   Placement  |
|                            ID       ID       Start:Size |
|=========================================================|
|   0  MIG 1g.5gb            19        9          6:1     |
+---------------------------------------------------------+
|   0  MIG 2g.10gb           14        3          4:2     |
+---------------------------------------------------------+
|   0  MIG 4g.20gb            5        2          0:4     |
+---------------------------------------------------------+

$ nvidia-smi mig -i 0 -lci
+--------------------------------------------------------------------+
| Compute instances:                                                 |
| GPU     GPU       Name             Profile   Instance   Placement  |
|       Instance                       ID        ID       Start:Size |
|         ID                                                         |
|====================================================================|
|   0      9       MIG 1g.5gb           0         0          0:1     |
+--------------------------------------------------------------------+
|   0      3       MIG 1c.2g.10gb       0         0          0:1     |
+--------------------------------------------------------------------+
|   0      3       MIG 1c.2g.10gb       0         1          1:1     |
+--------------------------------------------------------------------+
|   0      2       MIG 4g.20gb          3         0          0:4     |
+--------------------------------------------------------------------+

$ nvidia-smi -i 0
Tue Feb 17 16:58:38 2026
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.126.09             Driver Version: 580.126.09     CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA A100-SXM4-40GB          On  |   00000000:10:1C.0 Off |                   On |
| N/A   40C    P0             43W /  400W |     249MiB /  40960MiB |     N/A      Default |
|                                         |                        |              Enabled |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| MIG devices:                                                                            |
+------------------+----------------------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |              Shared Memory-Usage |        Vol|        Shared         |
|      ID  ID  Dev |                Shared BAR1-Usage | SM     Unc| CE ENC  DEC  OFA  JPG |
|                  |                                  |        ECC|                       |
|==================+==================================+===========+=======================|
|  0    2   0   0  |             142MiB / 20096MiB    | 56      0 |  4   0    2    0    0 |
|                  |               0MiB / 12211MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
|  0    3   0   1  |              71MiB /  9984MiB    | 14      0 |  2   0    1    0    0 |
|                  |               0MiB /  6105MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
|  0    3   1   2  |              71MiB /  9984MiB    | 14      0 |  2   0    1    0    0 |
|                  |               0MiB /  6105MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
|  0    9   0   3  |              36MiB /  4864MiB    | 14      0 |  1   0    0    0    0 |
|                  |               0MiB /  3052MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+

$ nvidia-smi -L
GPU 0: NVIDIA A100-SXM4-40GB (UUID: GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9)
  MIG 4g.20gb     Device  0: (UUID: MIG-c42101f0-a1fa-5b68-8908-7c5c887f28bd)
  MIG 1c.2g.10gb  Device  1: (UUID: MIG-8970491e-16e0-5140-9f8f-d561baa3c186)
  MIG 1c.2g.10gb  Device  2: (UUID: MIG-239565ce-30e3-52d7-8197-5630d3ce21fa)
  MIG 1g.5gb      Device  3: (UUID: MIG-20301a31-77fa-59ec-b0b8-7ef543821f29)
GPU 1: NVIDIA A100-SXM4-40GB (UUID: GPU-934e3c41-2e9a-efbf-5e75-a17cc8913c9e)
GPU 2: NVIDIA A100-SXM4-40GB (UUID: GPU-36441532-9ef4-0f3a-afb1-f844c3ab04bf)
GPU 3: NVIDIA A100-SXM4-40GB (UUID: GPU-ba4fa428-9d41-74cf-86e6-0824b0de1b09)
GPU 4: NVIDIA A100-SXM4-40GB (UUID: GPU-ab948b61-2346-9a55-872f-9c025479276d)
GPU 5: NVIDIA A100-SXM4-40GB (UUID: GPU-c634460f-e63f-6e47-e45a-2401ba173441)
GPU 6: NVIDIA A100-SXM4-40GB (UUID: GPU-9e9e32ec-1efc-2b7f-a94c-c985be7dcb8a)
GPU 7: NVIDIA A100-SXM4-40GB (UUID: GPU-e38bb82d-2bd3-41b0-1c6e-db7d90e6ae19)

# run
# ============================================================
# 방법 1: MIG UUID (가장 정확)
# ============================================================
CUDA_VISIBLE_DEVICES=MIG-c42101f0-a1fa-5b68-8908-7c5c887f28bd

# ============================================================
# 방법 2: MIG-GPU-<gpu-uuid>/<gi-id>/<ci-id>
# ============================================================
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/2/0   # 4g.20gb
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/3/0   # 1c.2g.10gb 첫번째
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/3/1   # 1c.2g.10gb 두번째
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/9/0   # 1g.5gb

# ============================================================
# 방법 3: GPU 인덱스 + GI/CI (UUID 불필요, 간편)
# ============================================================
CUDA_VISIBLE_DEVICES=0:2/0    # GPU 0, GI 2, CI 0 → 4g.20gb
CUDA_VISIBLE_DEVICES=0:3/0    # GPU 0, GI 3, CI 0 → 1c.2g.10gb 첫번째
CUDA_VISIBLE_DEVICES=0:3/1    # GPU 0, GI 3, CI 1 → 1c.2g.10gb 두번째
CUDA_VISIBLE_DEVICES=0:9/0    # GPU 0, GI 9, CI 0 → 1g.5gb

# ============================================================
# 여러 MIG 디바이스 동시 지정 (콤마 구분)
# ============================================================
CUDA_VISIBLE_DEVICES=MIG-c42101f0-...,MIG-8970491e-...
CUDA_VISIBLE_DEVICES=0:2/0,0:3/0


# 
# caps 파일 목록
ls -la /dev/nvidia-caps/
total 0
drwxr-xr-x.  2 root root     240 Feb 17 16:54 .
drwxr-xr-x. 16 root root    4020 Feb 17 16:23 ..
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

# 어떤 cap이 어떤 GI/CI인지
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

```shell
nvidia-smi mig.py -i 0 -m 1
```

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