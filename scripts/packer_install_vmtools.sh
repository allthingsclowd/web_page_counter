#!/usr/bin/env bash

sudo apt-get install -y perl open-vm-tools

sudo systemctl restart open-vm-tools

sudo apt-get autoremove -y
sudo apt-get clean

# Removing leftover leases and persistent rules
echo "cleaning up dhcp leases"
sudo rm /var/lib/dhcp/*

# Zero out the free space to save space in the final image:
# echo "Zeroing device to make space..."
# dd if=/dev/zero of=/EMPTY bs=1M
# rm -f /EMPTY

echo "The End!!!"
exit 0