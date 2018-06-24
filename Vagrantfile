Vagrant.configure("2") do |config|

    #override global variables to fit Vagrant setup
    ENV['REDIS_MASTER_NAME']||="masterredis01"
    ENV['REDIS_MASTER_IP']||="192.168.2.200"
    ENV['REDIS_SLAVE_NAME']||="slaveredis02"
    ENV['REDIS_SLAVE_IP']||="192.168.2.201"
    ENV['GO_DEV_IP']||="192.168.2.100"
    ENV['GO_DEV_NAME']||="godev01"
    ENV['GO_GUEST_PORT']||="808"
    ENV['GO_HOST_PORT']||="808"
    ENV['NGINX_NAME']||="web01"
    ENV['NGINX_IP']||="192.168.2.250"
    ENV['NGINX_GUEST_PORT']||="9090"
    ENV['NGINX_HOST_PORT']||="9090"
    ENV['VAULT_NAME']||="vault01"
    ENV['VAULT_IP']||="192.168.2.10"
    ENV['CONSUL_NAME']||="consul01"
    ENV['CONSUL_IP']||="192.168.2.11"
    ENV['LISTENER_COUNT']||="3"
    ENV['SERVER_COUNT']||="2"
    
    no_of_go_servers=ENV['SERVER_COUNT']

    #global config
    config.vm.synced_folder ".", "/vagrant"
    config.vm.synced_folder ".", "/usr/local/bootstrap"
    config.vm.box = "allthingscloud/go-counter-demo"
    config.vm.provision "shell", path: "scripts/install_consul.sh", run: "always"

    config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 1
    end

    config.vm.define "consul01" do |consul01|
        consul01.vm.hostname = ENV['CONSUL_NAME']
        consul01.vm.network "private_network", ip: ENV['CONSUL_IP']
        consul01.vm.network "forwarded_port", guest: 8500, host: 8500
    end

    config.vm.define "vault01" do |vault01|
        vault01.vm.hostname = ENV['VAULT_NAME']
        vault01.vm.network "private_network", ip: ENV['VAULT_IP']
        vault01.vm.network "forwarded_port", guest: 8200, host: 8200
        vault01.vm.provision :shell, path: "scripts/install_vault.sh", run: "always"
    end

    config.vm.define "redis01" do |redis01|
        redis01.vm.hostname = ENV['REDIS_MASTER_NAME']
        redis01.vm.network "private_network", ip: ENV['REDIS_MASTER_IP']
        redis01.vm.provision :shell, path: "scripts/install_redis.sh"
    end
    
    config.vm.define "redis02" do |redis02|
        redis02.vm.hostname = ENV['REDIS_SLAVE_NAME']
        redis02.vm.network "private_network", ip: ENV['REDIS_SLAVE_IP']
        redis02.vm.provision :shell, path: "scripts/install_redis.sh"
    end

    (1..2).each do |i|
        config.vm.define "godev0#{i}" do |devsvr|
            devsvr.vm.hostname = "godev0#{i}"
            devsvr.vm.network "private_network", ip: "192.168.2.10#{i}"
            devsvr.vm.network "forwarded_port", guest: "808#{i}", host: "808#{i}"
            devsvr.vm.provision "shell", path: "scripts/install_go_app.sh"
        end
    end

    config.vm.define "web01" do |web01|
        web01.vm.hostname = ENV['NGINX_NAME']
        web01.vm.network "private_network", ip: ENV['NGINX_IP']
        web01.vm.network "forwarded_port", guest: ENV['NGINX_GUEST_PORT'], host: ENV['NGINX_HOST_PORT']
        web01.vm.provision :shell, path: "scripts/install_webserver.sh"
   end

end
