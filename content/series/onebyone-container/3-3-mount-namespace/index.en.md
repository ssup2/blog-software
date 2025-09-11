---
title: 3.3. Mount Namespace
---

## Mount Namespace

```console {caption="[Shell 1] Check nginx Container Mount Information", linenos=table}
# Create Directory and File to use as Volume for nginx Container on Host
(host)# mkdir -p /mnt/nginx-volume
(host)# touch /mnt/nginx-volume/nginx-file

# Run nginx Container as Daemon and execute bash Process in nginx Container through exec
(host)# docker run -d --rm --name nginx -v /mnt/nginx-volume:/nginx-volume nginx:1.16.1
(host)# docker exec -it nginx bash

# Check Mount information in nginx Container
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

# Check Volume File in nginx Container
(nginx)# ls /nginx-volume
nginx-file
```

```console {caption="[Shell 2] Check httpd Container Mount Information", linenos=table}
# Create Directory and File to use as Volume for httpd Container on Host
(host)# mkdir -p /mnt/httpd-volume
(host)# touch /mnt/httpd-volume/httpd-file

# Run httpd Container as Daemon and execute bash Process in httpd Container through exec
(host)# docker run -d --rm --name httpd -v /mnt/httpd-volume:/httpd-volume httpd:2.4.43
(host)# docker exec -it httpd bash

# Check Mount information in httpd Container
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

# Check Volume File in nginx Container
(nginx)# ls /httpd-volume
httpd-file
```

Let's look at Mount Namespace, which is responsible for mount isolation. [Shell 1,2] show the process of creating a Volume used as a separate storage space for files in containers, attaching the created Volume to containers, and checking the attached Volume and container's mount information inside the container. The mount information visible in containers looks similar at first glance, but upon closer inspection, you can see that they have different mount information.

The root filesystem mounted on "/(Root)" of each container is marked as overlay and looks the same, but you can see that the mount options are different when you look at the mount options. Here, overlay refers to a special filesystem called OverlayFS, which is the most commonly used filesystem for configuring container root filesystems. OverlayFS will be explained in detail when explaining container images. In the case of nginx Container, since the Volume was attached to "/nginx-volume", you can see that the Volume information is also visible at "/nginx-volume" in the mount information. On the other hand, in the case of http Container, since the Volume was attached to "/http-volume", you can see that the Volume information is also visible at "/http-volume" in the mount information.

```console {caption="[Shell 3] Check Host Mount Information", linenos=table}
# Check nginx Container and httpd Container Root Directory paths
(host)# docker inspect nginx | jq -r '.[0].GraphDriver.Data.MergedDir'
/var/lib/docker/overlay2/60cdd9ada3570b00bcaa4d6d418b00f0424741e1f53c205477401eeff935f627/merged
(host)# docker inspect httpd | jq -r '.[0].GraphDriver.Data.MergedDir'
/var/lib/docker/overlay2/4af3d974a9c5adfcb7d7efb7437ab020e6289ae5b0d186265d5727d77748f5e0/merged

# Check Mount information in Host
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

[Shell 3] shows the process of creating nginx and httpd Containers and then querying the mount information visible from the Host. Looking at the mount information, you can see OverlayFS information. You can see that the first OverlayFS option in [Shell 3] is the same as the OverlayFS option of nginx Container's root filesystem. In other words, you can see that the first OverlayFS in [Shell 3] is the filesystem for nginx Container. In the same way, you can see that the second OverlayFS in [Shell 3] is the filesystem for http Container. The reason why each container and host can have different mount information is because of Mount Namespace.

{{< figure caption="[Figure 1] Mount Namespace" src="images/mount-namespace.png" width="700px" >}}

Mount Namespace means a Namespace that isolates mounts. The meaning of isolating mounts, when expanded, also means that the filesystem that each process can access can be isolated. [Figure 1] shows three Mount Namespaces: the Host Mount Namespace used by the Host, the netshoot-a Mount Namespace used by netshoot-a Container, and the netshoot-b Mount Namespace used by netshoot-b Container.

The Host Mount Namespace can access all filesystems, but the Container Mount Namespace can only access some filesystems. The filesystems that the Container Mount Namespace can access are only the filesystems under the Container Root. Therefore, the Host can access each container's filesystem, but each container cannot access the Host's filesystem or other containers' filesystems.

This operation method is similar to changing the root through the chroot() system call (chroot command) and then executing the process. However, when actually creating containers, the chroot() is not used, but a system call called pivot-root() is used. pivot-root() is used to change the root of the Mount Namespace to which the process that called pivot-root() belongs.

When a container is created, a dedicated Mount Namespace for the container is created, and the filesystem state of the created Container Mount Namespace is the same as the filesystem state of the Host Mount Namespace. This is because the filesystem information of the Host Mount Namespace is copied to the Container Mount Namespace since the Container Mount Namespace was created from the Host Mount Namespace. After that, pivot-root() is called to change the root of the Container Mount Namespace to the actual container root.

Generally, container management tools like Docker provide Volume functionality. Volumes are provided by connecting a specific directory of the Host to a specific directory of the Container. Therefore, when a container wants to access a specific file of the Host, it can be provided to the container through a Volume. This connection process is achieved through a special mount technique called Bind Mount provided by Linux. In [Shell 1,2], you can see that the nginx-file and http-file files created in the Volume are also visible identically in each container.

The reason why the Volume's filesystem in [Shell 1,2] is ext4 and the block device is /dev/sdb2 is because the Host's directory was bind-mounted, so the Host root's filesystem and block device are visible as they are. If you use this feature, you can easily find where the Volume is attached in the container just by using the mount command inside the container.
