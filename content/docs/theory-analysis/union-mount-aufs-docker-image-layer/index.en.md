---
title: Union Mount, AUFS, Docker Image Layer
---

This post briefly explains Union Mount and looks into AUFS, a Union Mount technique available on Linux. Finally, based on the AUFS content, it examines how Docker combines Image Layers into a single Image and creates Snapshots.

## 1. Union Mount

{{< figure caption="[Figure 1] Union Mount" src="images/union-mount.png" width="600px" >}}

As the name Union suggests, the operation of mounting multiple directories onto a specific directory at the same time is called a **Union Mount**. To use Union Mount in a Linux environment, AUFS can be used.

## 2. AUFS

AUFS (Advanced Multi Layered Unification Filesystem) is a technique that provides Union Mount in a Linux environment. AUFS is currently not included in the Main Stream of the Linux Kernel. However, since it is used as the default Filesystem for Docker Image Layers, AUFS is currently used in many places. In most Linux distributions, AUFS can be easily installed through a separate Package installation.

```console {caption="[Shell 1] AUFS Mount Command Example", linenos=table}
# mount -t aufs -o br=/layer-rw=rw:/layer-01=ro+wh:/layer-02=ro+wh:/layer-03=ro+wh none /mnt
```

The AUFS explanations below assume that the AUFS Mount was performed with the command and Options shown in [Shell 1]. In AUFS, the directories for the Union Mount are listed in `br` (Branch). It can be seen that the `/layer-rw` directory becomes the RW Branch and the remaining directories become RO Branches. Also, since `/layer-rw` is at the very front of the `br` option, `/layer-rw` becomes the Root Branch. The Branch directories are Union Mounted onto the `/mnt` directory.

AUFS uses **Whiteout** files to represent the deletion of files. By default, AUFS only refers to the Whiteout files inside the Root Branch, but if the `+wh` option is given, it also refers to the Whiteout files of the directories with the `+wh` option.

### 2.1. Read, Write

{{< figure caption="[Figure 2] Read, Write Operation Process in AUFS" src="images/aufs-read-write.png" width="600px" >}}

When the Branch directories contain different files, it is easy to predict that there is no problem even if the files of the Branch directories are gathered in a specific directory through the AUFS Mount. When the same file name exists in the same path, only the file of the last directory in the Branch list is visible inside the AUFS-mounted directory, as shown in [Figure 2]. In [Figure 2], the `file-01` file exists in both the `/layer-03` directory and the `/layer-01` directory, but only the `file-01` of `/layer-01` is visible inside the `/mnt` directory.

AUFS uses the COW (Copy on Write) approach. When a file is written in the `/mnt` directory, the written file is stored as-is in the RW Branch directory of AUFS. [Figure 2] shows the case where the `file-02` file is modified. When `file-02` is modified inside the `/mnt` directory, AUFS copies the entire **modified file** to the `/layer-rw` directory, not just the modified part. Only the modified `file-02` is visible inside the `/mnt` directory, but it can be seen that the original file is also kept intact inside the `/layer-02` directory.

### 2.2. Remove

{{< figure caption="[Figure 3] File, Directory Removal Process in AUFS" src="images/aufs-remove.png" width="600px" >}}

When a file or directory is deleted, a `.wh.<file-or-dir-name>` Whiteout file is created in the RW Branch directory, so the file is not visible inside the AUFS-mounted directory, but the original is kept. [Figure 3] shows the case where the `file-01` file is deleted. It also shows the role of a Whiteout file inside an RO Branch directory. Since the `+wh` option was given to the RO Branches at Mount time, the Whiteout file of an RO Branch hides the files of the lower Branches.

{{< figure caption="[Figure 4] Directory Removal and Creation Process in AUFS" src="images/aufs-remove-opq.png" width="600px" >}}

Among the Whiteout files of AUFS, there is a special Whiteout file called `.wh..wh..opq`. If a `.wh..wh..opq` file exists inside a specific directory of a Branch, all the files inside that directory of the lower Branches cannot be seen inside the AUFS-mounted directory. [Figure 4] shows the role of the `.wh..wh..opq` file. Since the `.wh..wh..opq` file exists in the `/dir` directory of the `/layer-rw` Branch, all the files inside the `/dir` directory of the lower `/layer-02` Branch are not visible in the `/mnt` directory. When the `dir` directory itself is deleted and then the `dir` directory is created again in the `/mnt` directory, AUFS handles it by creating a `.wh..wh..opq` file inside the `/dir` directory of the `/layer-rw` Branch, as shown in [Figure 4].

## 3. Docker Image Layer

```console {caption="[Shell 2] AUFS Mount Command Example Used by Docker", linenos=table}
# mount -t aufs -o br=/container-rw=rw:/ubuntu-base01=ro+wh:/ubuntu-base02=ro+wh:/ubuntu-base03=ro+wh none /container-root
```

{{< figure caption="[Figure 5] How Docker Uses AUFS" src="images/docker-image-layer.png" width="600px" >}}

Once AUFS is understood, it is possible to predict how Docker uses Image Layers. [Shell 2] and [Figure 5] show how Docker uses AUFS when creating a Container. When creating a Container, Docker creates a Root directory and an RW directory for the Container. Then Docker sets the Layers (directories) of the Base Image as RO Branches, sets the Container RW directory as the RW Branch, and performs the AUFS Mount onto the Root directory of the Container.

All the files modified or added while the Container is running remain in the RW directory of the Container, and the Base Image Layers, which are RO Branches, are not affected at all. Since the Base Image Layers are not modified, they can be shared with other Containers. Because the file changes of a Container remain only in the RW directory, Docker copies and manages only the Container RW directory when performing a Snapshot. When creating a Container that uses an image created from a Snapshot, Docker sets the copied RW directory as an RO Branch of the new Container and uses it. In this way, **one AUFS Branch** becomes **one Docker Image Layer**.

The Docker Daemon currently uses not only AUFS but also various filesystems such as ZFS and OverlayFS as its Backend filesystem. The explanation above applies only when AUFS is used. However, even if the Docker Daemon does not use AUFS as its Backend filesystem, when Uploading/Downloading a Docker Image, the Docker Image Layers are converted to the AUFS Branch format before the Upload/Download is performed. This is because the Image Spec declared by the OCI (Open Container Initiative) chose the AUFS Branch. In fact, if you download a Layer directly from the Docker Registry and decompress it, you can find the Whiteout files of AUFS.

## 4. References

* Container Image Spec : [https://github.com/opencontainers/image-spec](https://github.com/opencontainers/image-spec)
