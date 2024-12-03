---
title: Union Mount, AUFS, Docker Image Layer
---

Union Mount를 간략하게 설명하고 리눅스에서 이용할 수 있는 Union Mount기법인 AUFS에 대해 알아본다. 마지막으로 AUFS의 내용을 바탕으로 Docker가 Image Layer를 어떻게 하나의 Image로 만들고 Snapshot을 생성하는지 알아본다.

## 1. Union Mount

{{< figure caption="[Figure 1] Union Mount" src="images/union-mount.png" width="600px" >}}

Union이란 이름에서도 알 수 있듯이, 여러개의 폴더를 동시에 특정 폴더에 Mount하는 동작을 Union Mount라고 한다. 리눅스 환경에서 Union Mount를 이용하기 위해서는 AUFS를 이용하면 된다.

## 2. AUFS

AUFS (Advanced Multi Layered Unification Filesystem)은 리눅스 환경에서 Union Mount를 제공하는 기법이다. AUFS는 현재 Linux Kernel의 Main Stream에 포함되어 있지 않다. 하지만 Docker Image Layer의 기본 Filesystem으로 이용되고 있기 때문에 현재 많은 곳에서 AUFS를 이용하고 있다. 대부분의 리눅스 배포판에서는 별도의 Package 설치를 통해 AUFS를 쉽게 설치 할 수 있다.

```console {caption="[Shell 1] AUFS Mount 명령어 예제", linenos=table}
# mount -t aufs -o br=/layer-rw=rw:/layer-01=ro+wh:/layer-02=ro+wh:/layer-03=ro+wh none /mnt
```

아래의 AUFS 설명들은 [Shell 1]과 같은 명령어와 Option을 통해 AUFS Mount를 했다고 가정하에 진행한다. AUFS는 **br(Branch)**에 Union Mount를 위한 폴더들을 나열한다. /layer-rw 폴더는 RW Branch가 되고 나머지 폴더들은 RO Branch가 되는것을 확인 할 수 있다. 또한 /layer-rw가 br 옵션의 가장 앞에 있기 때문에 /layer-rw는 Root Branch가 된다. /mnt 폴더에 Branch 폴더들이 Union Mount 된다.

AUFS에서는 파일의 삭제를 나타내기 위해 **Whiteout** 파일을 이용한다. 기본적으로 AUFS는 Root Branch안에 있는 Whiteout 파일만 참조하지만 +wh 옵션을 주면 +wh 옵션이 있는 폴더의 Whiteout 파일도 참조한다.

### 2.1. Read, Write

{{< figure caption="[Figure 2] AUFS에서 Read, Write 수행시 동작 과정" src="images/aufs-read-write.png" width="600px" >}}

Branch 폴더들이 서로 다른 파일들을 갖고있는 경우 AUFS Mount를 통해 특정 폴더에 Brach 폴더의 파일들이 모여도 문제가 없다는걸 예측 할 수 있다. 동일한 경로에 동일한 파일 이름이 있는 경우, [Figure 2]처럼 AUFS Mount가 된 폴더내에서는 오직 Branch의 가장 마지막에 있는 폴더의 파일만 볼 수 있다. [Figure 2]에서 file-01 파일은 /layer-03 폴더와 /layer-01 폴더에 있지만 /mnt 폴더 내에서는 /layer-01의 file-01만 보이게 된다.

AUFS는 COW(Copy on Write)방식을 이용한다. /mnt 폴더에서 파일을 쓰는 경우, 써진 파일은 AUFS의 RW Branch 폴더에 그대로 저장된다. [Figure 2]는 file-02 파일이 변경될때를 나타내고 있다. /mnt 폴더 내에서 file-02를 변경하는 경우 AUFS는 변경된 일부분이 아니라 **변경된 파일** 전체를 /layer-rw 폴더에 복사한다. /mnt 폴더 내에서는 변경된 file-02만 보이지만 /layer-02 폴더안에 원본 파일도 그대로 유지되는 것을 알 수 있다.

### 2.2. Remove

{{< figure caption="[Figure 3] AUFS에서 File, Directory 제거시 동작 과정" src="images/aufs-remove.png" width="600px" >}}

파일이나 폴더를 지우는 경우 RW Branch 폴더에 .wh.<file-or-dir-name> Writeout 파일을 생성하여 AUFS Mount가 된 폴더 내에서는 파일이 안보이지만, 원본은 유지된다. [Figure 3]에서는 file-01 파일을 삭제할 경우를 나타내고 있다. 또한 RO Branch 폴더안에 있는 Whiteout 파일의 역할도 나타내고 있다. Mount시 RO Branch에 +wh 옵션을 주었기 때문에 RO Branch의 Whiteout 파일이 하위 Branch의 파일을 숨긴다.

{{< figure caption="[Figure 4] AUFS에서 Directory 제거 및 생성시 동작 과정" src="images/aufs-remove-opq.png" width="600px" >}}

AUFS의 Whiteout 파일중 .wh..wh..opq라는 특수한 Whiteout 파일이 있다. Branch의 특정 폴더내에 .wh..wh..opq 파일이 있으면 하위 Branch들의 해당 폴더내의 모든 파일들은 AUFS Mount가 된 폴더내에서 볼 수 없다. [Figure 4]는 .wh..wh..opq 파일의 역할을 나타내고 있다. /layer-rw Branch의 /dir 폴더에 .wh..wh..opq 파일이 있기 때문에 하위 /layer-02 Branch의 /dir폴더 안에 있는 모든 파일들은 /mnt 폴더에서 보이지 않는다. /mnt 폴더에서 dir 폴더 자체를 삭제했다가 다시 dir 폴더를 생성하는 경우, AUFS는 [Figure 4]처럼 /layer-rw Branch의 /dir 폴더안에 .wh..wh..opq 파일 생성을 통해 처리한다.

## 3. Docker Image Layer

```console {caption="[Shell 2] Docker에서 이용하는 AUFS Mount 명령어 예제", linenos=table}
# mount -t aufs -o br=/container-rw=rw:/ubuntu-base01=ro+wh:/ubuntu-base02=ro+wh:/ubuntu-base03=ro+wh none /container-root
```

{{< figure caption="[Figure 5] Docker에서 AUFS를 이용하는 방법" src="images/docker-image-layer.png" width="600px" >}}

AUFS를 이해했다면 Docker가 어떻게 Image Layer를 이용하는지 예측 할 수 있다. [Shell 2]와 [Figure 5]는 Docker가 Container 생성시 AUFS를 어떻게 이용하는지를 나타내고 있다. Docker는 Container 생성시 Container를 위한 Root 폴더와 RW 폴더를 생성한다. 그 후 Docker는 Base Image의 Layer(폴더)들을 RO Branch로 설정하고, Container RW 폴더를 RW Branch로 설정하여 Container의 Root 폴더에 AUFS Mount를 수행한다.

Container가 동작하면서 변경하거나 추가한 파일들은 모두 Container의 RW 폴더에 남게되고 RO Branch들인 Base Image Layer들에게는 전혀 영향을 주지 않는다. Base Image Layer들은 변경되지 않으므로 다른 Container들과 공유해서 사용 가능하다. Container의 파일 변경 내용은 RW 폴더에만 남기 때문에 Docker는 Snapshot 수행시 Container RW 폴더만 복사하여 관리한다. Snapshot으로 생성한 이미지를 이용하는 Container를 생성 할 경우 Docker는 복사해둔 RW 폴더를 새로운 Container의 RO Branch로 설정하여 이용한다. 이와 같이 **하나의 AUFS Branch가 하나의 Docker Image Layer**가 된다.

Docker Daemon은 현재 AUFS뿐만 아니라 ZFS, OverlayFS 등 다양한 파일시스템을 Backend 파일시스템으로 이용하고 있다. 위 설명은 AUFS를 이용할 경우에만 해당한다. 하지만 Docker Daemon이 AUFS를 Backend 파일시스템으로 이용하고 있지 않더라도 Docker Image를 Upload/Download 할때에는 Docker Image Layer는 AUFS Branch 규격으로 변환 후 Upload/Download를 수행한다. OCI(Open Container Initiative)에서 선언한 Image Spec이 AUFS Branch를 선택했기 때문이다. 실제로 Docker Registry에서 직접 Layer를 받아 압축을 풀어보면 AUFS의 Whiteout 파일을 확인 할 수 있다.

## 4. 참조

* Container Image Spec : [https://github.com/opencontainers/image-spec](https://github.com/opencontainers/image-spec)
