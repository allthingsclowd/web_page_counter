Vagrant.configure("2") do |config|

    ENV['REDIS_MASTER_NAME']||="redis01"
    ENV['REDIS_MASTER_IP']||="192.168.2.200"
    ENV['REDIS_SLAVE_NAME']||="redis02"
    ENV['REDIS_SLAVE_IP']||="192.168.2.201"
    ENV['GO_DEV_IP']||="192.168.2.100"
    ENV['GO_DEV_NAME']||="godev01"
    ENV['GO_GUEST_PORT']||="8080"
    ENV['GO_HOST_PORT']||="8080"
    ENV['NGINX_NAME']||="web01"
    ENV['NGINX_IP']||="192.168.2.250"
    ENV['NGINX_GUEST_PORT']||="9090"
    ENV['NGINX_HOST_PORT']||="9090"

    #global config
    config.vm.synced_folder ".", "/vagrant"
    config.vm.synced_folder ".", "/usr/local/bootstrap"
    config.vm.box = "cbednarski/ubuntu-1604"
    config.vm.provision "shell", path: "scripts/consul.sh", run: "always"

    config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 1
    end

    config.vm.define "consul01" do |consul01|
        consul01.vm.hostname = "consul01"
        consul01.vm.network "private_network", ip: "192.168.2.11"
        consul01.vm.network "forwarded_port", guest: 8500, host: 8500
    end

    config.vm.define "redis01" do |redis01|
        redis01.vm.hostname = ENV['REDIS_MASTER_NAME']
        redis01.vm.network "private_network", ip: ENV['REDIS_MASTER_IP']
        redis01.vm.provision :shell, path: "scripts/redis_base.sh"
        redis01.vm.provision :shell, path: "scripts/redis_master.sh"
    end
    
    config.vm.define "redis02" do |redis02|
        redis02.vm.hostname = ENV['REDIS_SLAVE_NAME']
        redis02.vm.network "private_network", ip: ENV['REDIS_SLAVE_IP']
        redis02.vm.provision :shell, path: "scripts/redis_base.sh"
        redis02.vm.provision :shell, path: "scripts/redis_slave.sh"
    end
    
    config.vm.define "godev01" do |devsvr|
        devsvr.vm.hostname = ENV['GO_DEV_NAME']
        devsvr.vm.network "private_network", ip: ENV['GO_DEV_IP']
        devsvr.vm.network "forwarded_port", guest: ENV['GO_GUEST_PORT'], host: ENV['GO_HOST_PORT']
        devsvr.vm.provision "shell", path: "scripts/go_init.sh"
        devsvr.vm.provision "shell", path: "scripts/go_vagrant_user.sh"
    end

    config.vm.define "web01" do |web01|
        web01.vm.hostname = ENV['NGINX_NAME']
        web01.vm.network "private_network", ip: ENV['NGINX_IP']
        web01.vm.network "forwarded_port", guest: ENV['NGINX_GUEST_PORT'], host: ENV['NGINX_HOST_PORT']
        web01.vm.provision :shell, path: "scripts/webserver_install.sh"
   end

end
