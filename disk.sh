#!/bin/bash

# 显示所有可用的硬盘和分区
echo "当前系统中所有的硬盘和分区："
lsblk

# 提示用户输入硬盘设备和挂载点
read -p "请输入硬盘设备（例如 /dev/sdb）： " DEVICE
read -p "请输入挂载点（例如 /mnt/mydisk）： " MOUNT_POINT

# 检查硬盘是否存在
if [ ! -b "$DEVICE" ]; then
  echo "硬盘 $DEVICE 不存在！"
  exit 1
fi

# 创建挂载点
echo "正在创建挂载点 $MOUNT_POINT ..."
sudo mkdir -p $MOUNT_POINT

# 挂载硬盘
echo "正在挂载硬盘 $DEVICE 到 $MOUNT_POINT ..."
sudo mount $DEVICE $MOUNT_POINT

# 验证挂载是否成功
if mount | grep "$MOUNT_POINT" > /dev/null; then
  echo "硬盘成功挂载到 $MOUNT_POINT !"
else
  echo "挂载失败，请检查错误信息。"
  exit 1
fi

# 获取硬盘 UUID
UUID=$(sudo blkid -o value -s UUID $DEVICE)

# 选择是否设置开机自动挂载
read -p "是否将硬盘设置为开机自动挂载？(y/N): " AUTO_MOUNT

if [[ "$AUTO_MOUNT" == "y" || "$AUTO_MOUNT" == "Y" ]]; then
  echo "正在配置开机自动挂载 ..."
  
  # 编辑 /etc/fstab，加入自动挂载配置
  echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab

  echo "开机自动挂载配置已添加到 /etc/fstab 文件。"
else
  echo "未设置开机自动挂载。"
fi

# 完成
echo "挂载过程完成。"
