---
title: 服务器管理
categories:
  - Linux
tags:
  - Ubuntu
  - Linux
description: 
published: false
---

## swapfile

```shell
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# permenant
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

sudo swapoff /swapfile
sudo rm /swapfile
```

## ssh key

```shell
ssh-keygen -t ed25519 -C "your-email@example.com"
ssh-copy-id -i ~/.ssh/your_key_name user@remote-host

~/.ssh/config
Host remote-host
    HostName remote-host.com
    User your-username
    IdentityFile ~/.ssh/your_key_name
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 30
    TCPKeepAlive yes

ssh remote-host
```

