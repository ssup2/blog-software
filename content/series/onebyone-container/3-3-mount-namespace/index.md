---
title: 3.3. Mount Namespace
---

## Mount Namespace

```console {caption="[Shell 1] nginx Container의 Mount 정보 확인", linenos=table}
# Host에 nginx Container의 Volume으로 이용할 Directory 생성 및 File 생성 
(host)# mkdir -p /mnt/nginx-volume
(host)# touch /mnt/nginx-volume/nginx-file

# nginx Container를 Daemon으로 실행하고 exec을 통해서 nginx Container에 bash Process를 실행
(host)# docker run -d --rm --name nginx -v /mnt/nginx-volume:/nginx-volume nginx:1.16.1
(host)# docker exec -it nginx bash

# nginx Container에서 Mount 정보 확인
(nginx)# mount
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/WUNBNTYW62TMMOJSIAFQMNMQJJ:/var/lib/docker/overlay2/l/NSC2BEHEQGKZL5SXOH4P7KYECG:/var/lib/docker/overlay2/l/PVUAREBB632TUQ3QJTC7O6SFRV:/var/lib/docker/overlay2/l/FW46EL2U6PWL3BIHHACTIIE53N,upperdir=/var/lib/docker/overlay2/60cdd9ada3570b00bcaa4d6d418b00f0424741e1f53c205477401eeff935f627/diff,workdir=/var/lib/docker/overlay2/60cdd9ada3570b00bcaa4d6d418b00f0424741e1f53c205477401eeff935f627/work)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
tmpfs on /dev type tmpfs (rw,nosuid,size=65536k,mode=755)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=666)
sysfs on /sys type sysfs (ro,nosuid,nodev,noexec,relatime)
tmpfs on /sys/fs/cgroup type tmpfs (ro,nosuid,nodev,noexec,relatime,mode=755)
...
/dev/sda2 on /nginx-volume type ext4 (rw,relatime,data=ordered)
...

# nginx Container에서 Volume의 File 확인
(nginx)# ls /nginx-volume
nginx-file
```

```console {caption="[Shell 2] httpd Container의 Mount 정보 확인", linenos=table}
# Host에 httpd Container의 Volume으로 이용할 Directory 생성 및 File 생성 
(host)# mkdir -p /mnt/httpd-volume
(host)# touch /mnt/httpd-volume/httpd-file

# httpd Container를 Daemon으로 실행하고 exec을 통해서 httpd Container에 bash Process를 실행
(host)# docker run -d --rm --name httpd -v /mnt/httpd-volume:/httpd-volume httpd:2.4.43
(host)# docker exec -it httpd bash

# httpd Container에서 Mount 정보 확인
(httpd)# mount
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/25BMCB5TMIJIGCXBPYGABX4VV3:/var/lib/docker/overlay2/l/RP6BFGRYNFHDHH3LADBIHK7RKS:/var/lib/docker/overlay2/l/GVVCUIKIMMAQWODR7MXUDNZ2ED:/var/lib/docker/overlay2/l/T52KDQTNBHR6KNC47WM64ISHKE:/var/lib/docker/overlay2/l/NXDEMBX7ZWJT6QZKOPJEHUXRQZ:/var/lib/docker/overlay2/l/D5TZIT4QTMFPUNXZNTB3DZNSLZ,upperdir=/var/lib/docker/overlay2/4af3d974a9c5adfcb7d7efb7437ab020e6289ae5b0d186265d5727d77748f5e0/diff,workdir=/var/lib/docker/overlay2/4af3d974a9c5adfcb7d7efb7437ab020e6289ae5b0d186265d5727d77748f5e0/work)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
tmpfs on /dev type tmpfs (rw,nosuid,size=65536k,mode=755)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=666)
sysfs on /sys type sysfs (ro,nosuid,nodev,noexec,relatime)
tmpfs on /sys/fs/cgroup type tmpfs (ro,nosuid,nodev,noexec,relatime,mode=755)
...
/dev/sda2 on /httpd-volume type ext4 (rw,relatime,data=ordered)
...

# nginx Container에서 Volume의 File 확인
(nginx)# ls /httpd-volume
httpd-file
```

Mount 격리를 담당하는 Mount Namespace를 알아본다. [Shell 1,2]는 Container에서 File을 별도로 저장하는 공간으로 이용하는 Volume을 생성하고, 생성한 Volume을 Container에 붙이고, Container안에서 붙인 Volume과 Container의 Mount 정보를 확인하는 과정을 나타내고 있다. Container에서 보이는 Mount 정보는 얼핏보면 동일해 보이지만 자세히 보면 서로 다른 Mount 정보를 갖고 있는것을 확인 할 수 있다.

각 Container의 "/(Root)"에 Mount되어 있는 Root Filesystem은 overlay라고 명시되어 있고 동일해 보이지만 Mount Option을 보면 Mount Option이 다른걸 확인할 수 있다. 여기서 overlay는 OverlayFS이라고 불리는 특수 Filesystem을 의미하며 Container의 Root Filesystem을 구성하는데 가장 많이 이용되는 Filesystem이다. OverlayFS은 Container Image를 설명할 때 자세히 설명할 예정이다. nginx Container의 경우 Volume을 "/nginx-volume"에 붙였기 때문에 Mount 정보에도 "/nginx-volume"에 Volume 정보가 보이는것을 확인할 수 있다. 반면 http Container의 경우 Volume을 "/http-volume"에 붙였기 때문에 Mount 정보에도 "/http-volume"에 Volume 정보가 보이는 것을 확인할 수 있다.

```console {caption="[Shell 3] Host의 Mount 정보 확인", linenos=table}
# nginx Container와 httpd Container의 Root Directory 경로 확인
(host)# docker inspect nginx | jq -r '.[0].GraphDriver.Data.MergedDir'
/var/lib/docker/overlay2/60cdd9ada3570b00bcaa4d6d418b00f0424741e1f53c205477401eeff935f627/merged
(host)# docker inspect httpd | jq -r '.[0].GraphDriver.Data.MergedDir'
/var/lib/docker/overlay2/4af3d974a9c5adfcb7d7efb7437ab020e6289ae5b0d186265d5727d77748f5e0/merged

# Host에서 Mount 정보 확인
(host)# mount
sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
udev on /dev type devtmpfs (rw,nosuid,relatime,size=4052788k,nr-inodes=1013197,mode=755)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000)
tmpfs on /run type tmpfs (rw,nosuid,noexec,relatime,size=816852k,mode=755)
/dev/sda2 on / type ext4 (rw,relatime,data=ordered)
...
overlay on /var/lib/docker/overlay2/60cdd9ada3570b00bcaa4d6d418b00f0424741e1f53c205477401eeff935f627/merged type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/WUNBNTYW62TMMOJSIAFQMNMQJJ:/var/lib/docker/overlay2/l/NSC2BEHEQGKZL5SXOH4P7KYECG:/var/lib/docker/overlay2/l/PVUAREBB632TUQ3QJTC7O6SFRV:/var/lib/docker/overlay2/l/FW46EL2U6PWL3BIHHACTIIE53N,upperdir=/var/lib/docker/overlay2/60cdd9ada3570b00bcaa4d6d418b00f0424741e1f53c205477401eeff935f627/diff,workdir=/var/lib/docker/overlay2/60cdd9ada3570b00bcaa4d6d418b00f0424741e1f53c205477401eeff935f627/work)
overlay on /var/lib/docker/overlay2/4af3d974a9c5adfcb7d7efb7437ab020e6289ae5b0d186265d5727d77748f5e0/merged type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/25BMCB5TMIJIGCXBPYGABX4VV3:/var/lib/docker/overlay2/l/RP6BFGRYNFHDHH3LADBIHK7RKS:/var/lib/docker/overlay2/l/GVVCUIKIMMAQWODR7MXUDNZ2ED:/var/lib/docker/overlay2/l/T52KDQTNBHR6KNC47WM64ISHKE:/var/lib/docker/overlay2/l/NXDEMBX7ZWJT6QZKOPJEHUXRQZ:/var/lib/docker/overlay2/l/D5TZIT4QTMFPUNXZNTB3DZNSLZ,upperdir=/var/lib/docker/overlay2/4af3d974a9c5adfcb7d7efb7437ab020e6289ae5b0d186265d5727d77748f5e0/diff,workdir=/var/lib/docker/overlay2/4af3d974a9c5adfcb7d7efb7437ab020e6289ae5b0d186265d5727d77748f5e0/work)
...
```

[Shell 3]은 nginx, httpd Container를 생성한 다음 Host에서 보이는 Mount 정보를 조회하는 과정을 나타내고 있다. Mount 정보를 살펴보면 OverlayFS 정보를 확인할 수 있다. [Shell 3]의 첫번째 OverlayFS의 Option은 nginx Container의 Root Filesystem인 OverlayFS의 Option과 동일한것 알 수 있다. 즉 [Shell 3]의 첫번째 OverlayFS은 nginx Container를 위한 Filesystem인걸 알 수 있다. 이와 동일한 방법으로 [Shell 3]의 두번째 OverlayFS은 http Container를 위한 Filesystem인걸 알 수 있다. 각 Container와 Host가 각각 다른 Mount 정보를 갖을수 있는 이유는 Mount Namespace 때문이다. 

{{< figure caption="[Figure 1] Mount Namespace" src="images/mount-namespace.png" width="700px" >}}

Mount Namespace는 Mount를 격리하는 Namespace를 의미한다. Mount를 격리한다는 의미는 좀더 확장하면 각 Process가 접근할 수 있는 Filesystem의 격리시킬수 있다는 의미도 된다. [Figure 1]은 Host가 이용하는 Host Mount Namespace, netshoot-a Container가 이용하는 netshoot-a Mount Namespace, netshoot-b Container가 이용하는 netshoot-b Mount Namespace, 3개의 Mount Namespace를 나타내고 있다. 

Host Mount Namespace는 모든 Filesystem에 접근이 가능하지만 Container Mount Namespace는 일부 Filesystem에만 접근할 수 있다. Container Mount Namespace가 접근할 수 있는 Filesystem은 Container Root의 하위 Filesystem들 뿐이다. 따라서 Host는 각 Container의 Filesystem에 접근할 수 있지만, 각 Container는 Host의 Filesystem이나 다른 Container의 Filesystem에는 접근할 수 없다.

이와 같은 동작 방식은 chroot() System Call(chroot 명령어)을 통해서 Root를 변경한 다음 Process를 실행하는 방법과 유사하다. 하지만 실제로 Container를 생성할때는 chroot()을 이용하지 않고 pivot-root()라고 불리는 System Call을 이용한다. pivot-root()은 pivot-root()를 호출한 Process가 속해 있는 Mount Namespace의 Root를 변경하는 용도로 이용된다. 

Container가 생성될때 Container 전용 Mount Namespace가 생성되며, 생성된 Container Mount Namespace의 Filesystem의 상태는 Host Mount Namespace의 Filesystem의 상태와 동일하다. Host Mount Namespace에서 Container Mount Namespace를 생성하였기 때문에 Host Mount Namespace의 Filesystem 정보가 Container Mount Namespace로 복제되기 때문이다. 그 이후 pivot-root()을 호출하여 Container Mount Namespace의 Root를 실제 Container Root로 변경한다.

일반적으로 Docker와 같은 Container 관리 도구는 Volume 기능을 제공한다. Volume은 Host의 특정 Directory를 Container의 특정 Directory에 연결하여 제공된다. 따라서 Host의 특정 File을 Container가 접근하고 싶을때, Volume을 통해서 Container에게 제공할 수 있다. 이러한 연결 과정은 Bind Mount라고 불리는 Linux에서 제공하는 특수 Mount 기법을 통해서 이루어진다. [Shell 1,2]에서 Volume안에 생성한 nginx-file, http-file File이 각 Container안에서도 동일하게 보이는것을 확인할 수 있다.

[Shell 1,2]에서 Volume의 Filesystem이 ext4로 되어 있고, Block Device가 /dev/sdb2인 이유는 Host의 Directory를 Bind Mount하였기 때문에 Host Root의 Filesystem과 Block Device가 그대로 보이는 것이다. 이러한 특징을 이용한다면 Container안에서 Mount 명령어 만으로 Container 어디에 Volume이 붙어있는지 쉽게 찾을 수 있다.