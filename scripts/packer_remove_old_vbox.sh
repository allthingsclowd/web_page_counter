# Without libdbus virtualbox would not start automatically after compile
apt-get -y install --no-install-recommends libdbus-1-3

# Install Linux headers and compiler toolchain
apt-get -y install build-essential linux-headers-$(uname -r)

# The netboot installs the VirtualBox support (old) so we have to remove it
service virtualbox-ose-guest-utils stop
rmmod vboxguest
apt-get purge -y virtualbox-ose-guest-x11 virtualbox-ose-guest-dkms virtualbox-ose-guest-utils
apt-get install -y dkms virtualbox-guest-dkms linux-headers-virtual

echo 'Removed old Vbox support'
shutdown -r now
sleep 60
