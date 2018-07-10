apt-get clean
apt-get update
apt-get upgrade -y

# Update to the latest kernel
apt-get install -y linux-generic linux-image-generic linux-server

# Hide Ubuntu splash screen during OS Boot, so you can see if the boot hangs
apt-get remove -y plymouth-theme-ubuntu-text
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
update-grub

apt-get install -y wget unzip git redis-server nginx lynx

which /usr/local/go &>/dev/null || {
    mkdir -p /tmp/go_src
    pushd /tmp/go_src
    [ -f go1.10.3.linux-amd64.tar.gz ] || {
        wget -nv https://dl.google.com/go/go1.10.3.linux-amd64.tar.gz
    }
    tar -C /usr/local -xzf go1.10.3.linux-amd64.tar.gz
    popd
    rm -rf /tmp/go_src
    echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile
}


# Reboot with the new kernel
shutdown -r now
sleep 60
