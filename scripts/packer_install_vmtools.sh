#!/usr/bin/env bash

sudo apt-get install -y perl open-vm-tools

# Hack to fix ubuntu 18.04 linux customisations bug
tmpfile=/tmp/bananas
sudo cp /lib/systemd/system/open-vm-tools.service ${tmpfile} &&
awk '/Unit/ { print; print "After=dbus.service"; next }1' ${tmpfile} | sudo tee /lib/systemd/system/open-vm-tools.service > /dev/null
sudo rm ${tmpfile}

sudo sed -i "s/D \/tmp 1777 root root -/#D \/tmp 1777 root root -/"  /usr/lib/tmpfiles.d/tmp.conf

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

# awk '/Unit/ { print; print "After=dbus.service"; next }1' /lib/systemd/system/open-vm-tools.service

tmpfile=/tmp/bananas
cp /lib/systemd/system/open-vm-tools.service ${tmpfile} &&
awk '/Unit/ { print; print "After=dbus.service"; next }1' ${tmpfile} | sudo tee /lib/systemd/system/open-vm-tools.service > /dev/null
rm ${tmpfile}