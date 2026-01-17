---
title: C NFSv4 Mount Function
---

This document summarizes C language-based NFSv4 mount functions that work in Linux and FreeBSD environments.

## 1. Linux NFSv4 Mount Function

```c {caption="[Code 1] Linux NFS4 Mount Function", linenos=table}
int linux_mount_nfs4(char *mount_point, char *server_ip, char *server_path)
{
    int result;
    char tmp_server_path[128] = {'\0',};
    char tmp_option[128] = {'\0',};

    strcpy(tmp_server_path, ":");
    strcat(tmp_server_path, server_path);

    strcpy(tmp_option, "nolock,addr=");
    strcat(tmp_option, server_ip);

    result = mount(tmp_server_path, mount_point, "nfs4", 0, tmp_option);

    if(result == 0)
        return 1;
    else
        return -1;
}
```

[Code 1] is a function that performs NFSv4 mount using the `mount()` function in a Linux environment. The Linux man page does not document how to perform NFSv4 mount using the `mount()` function.

## 2. FreeBSD NFSv4 Mount Function

```c {caption="[Code 2] FreeBSD NFS4 Mount Function", linenos=table}
int linux_mount_nfs4(char *mount_point, char *server_ip, char *server_path)
static void build_iovec(struct iovec **iov, int *iovlen, const char *name, void *val, size_t len)
{
        int i;

        if (*iovlen < 0)
                return;
        i = *iovlen;
        *iov = realloc(*iov, sizeof(**iov) * (i + 2));
        if (*iov == NULL) {
                *iovlen = -1;
                return;
        }
        (*iov)[i].iov_base = strdup(name);
        (*iov)[i].iov_len = strlen(name) + 1;
        i++;
        (*iov)[i].iov_base = val;
        if (len == (size_t)-1) {
                if (val != NULL)
                        len = strlen(val) + 1;
                else
                        len = 0;
        }
        (*iov)[i].iov_len = (int)len;
        *iovlen = ++i;
}

static void clean_iovec(struct iovec *iov, int iovlen){
    int i;
    for(i = iovlen-2; i >= 0; i=-2)
        free(iov[i].iov_base);
    free(iov);
}

static int freebsd_mount_nfs4(char *mount_point, char *server_ip, char *server_path)
{
    CLIENT *clp;
    struct iovec *iov = NULL;
    struct addrinfo hints, *ai_nfs;
    struct sockaddr *addr;
    struct netconfig *nconf;
    struct netbuf nfs_nb;

    char errmsg[] = "NFSv4 Mount Error!";
    char hostname[128];
    char *netid;
    int iovlen = 0;
    int addrlen = 0;
    int result;

    // Get network info
    memset(&hints, 0, sizeof(hints));
    hints.ai_flags = AI_NUMERICHOST;
    hints.ai_socktype = SOCK_STREAM;
    if(getaddrinfo(server_ip, "2049", NULL, &ai_nfs) != 0)
        return -1;

    // Check working of NFSv4 server.
    nfs_nb.buf = ai_nfs->ai_addr;
    nfs_nb.len = ai_nfs->ai_addrlen;
    nconf = getnetconfigent("tcp");
    clp = clnt_tli_create(RPC_ANYFD, nconf, &nfs_nb, NFS_PROGRAM, 4, 0, 0);
    if(clp == NULL)
        return -1;
    clnt_destroy(clp);

    // Set parameters
    sprintf(hostname,"%s:%s", server_ip, server_path);
    build_iovec(&iov, &iovlen, "hostname", hostname, (size_t)-1);
    build_iovec(&iov, &iovlen, "addr", ai_nfs->ai_addr, ai_nfs->ai_addrlen);
    build_iovec(&iov, &iovlen, "dirpath", server_path, (size_t)-1);

    build_iovec(&iov, &iovlen, "fstype", "nfs", (size_t)-1);
    build_iovec(&iov, &iovlen, "nfsv4", NULL, 0);
    build_iovec(&iov, &iovlen, "fspath", mount_point, (size_t)-1);
    build_iovec(&iov, &iovlen, "errmsg", errmsg, sizeof(errmsg));

    // Mount
    result = nmount(iov, iovlen, 0);

    clean_iovec(iov, iovlen);
    freeaddrinfo(ai_nfs);

    if(result == 0)
        return 1;
    else
        return -1;
}
```

[Code 2] is a function that performs NFSv4 mount using the `mount()` function in a FreeBSD environment. It was created by referencing FreeBSD's mount_nfs tool. When checking the NFSv4 server status at line 57, the NFSv4 server is working fine, but if a problem occurs with the NFSv4 server when executing the `nmount()` function at line 78, the `nmount()` function blocks.

## 3. References

* Linux : [http://stackoverflow.com/questions/28350912/nfs-mount-system-call-in-linux](http://stackoverflow.com/questions/28350912/nfs-mount-system-call-in-linux)
* FreeBSD : [https://github.com/freebsd/freebsd/blob/master/sbin/mount_nfs/mount_nfs.c](https://github.com/freebsd/freebsd/blob/master/sbin/mount_nfs/mount_nfs.c)

