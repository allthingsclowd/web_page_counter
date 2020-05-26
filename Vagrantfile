info = <<-'EOF'

      Welcome to The TAM HashiStack demo
        
                on Vagrant

      Open a browser on the following URLs to access each service

      WebPageCounter Application FrontEnd (public)  -   http://${NGINX_PUBLIC_IP}:9091
      WebPageCounter Application BackEnd (public)   -   http://${NGINX_PUBLIC_IP}:9090
      WebPageCounter Application FrontEnd -   http://${LEADER_IP}:9091
      WebPageCounter Application BackEnd  -   http://${LEADER_IP}:9090      
      Nomad Portal  (public)  -   https://${NGINX_PUBLIC_IP}:4646
      Vault Portal  (public)  -   https://${NGINX_PUBLIC_IP}:8200
      Consul Portal (public)  -   https://${NGINX_PUBLIC_IP}:8321
      Nomad Portal    -   https://${LEADER_IP}:4646
      Vault Portal    -   https://${LEADER_IP}:8200
      Consul Portal   -   https://${LEADER_IP}:8321      
      (self-signed certificates located in ../certificate-config directory)

      Vault Password  -   reallystrongpassword
      Consul ACL      -   Navigate to Vault to locate the consul ACL token then use it to login to the Consul portal


WARNING: PLEASE DON'T USE THESE CERTIFICATES IN ANYTHING OTHER THAN THIS TEST LAB!!!!
The keys are clearly publically available for demonstration purposes.

EOF

Vagrant.configure("2") do |config|

    #override global variables to fit Vagrant setup
    ENV['REDIS_MASTER_NAME']||="masterredis01"
    ENV['REDIS_MASTER_IP']||="192.168.9.200"
    ENV['GO_GUEST_PORT']||="808"
    ENV['GO_HOST_PORT']||="808"
    ENV['NGINX_NAME']||="web01"
    ENV['NGINX_IP']||="192.168.9.250"
    ENV['NGINX_PUBLIC_IP']||="192.168.94.90"
    ENV['NGINX_GUEST_PORT']||="9090"
    ENV['NGINX_HOST_PORT']||="9090"
    ENV['VAULT_NAME']||="vault01"
    ENV['VAULT_IP']||="192.168.9.10"
    ENV['LEADER_NAME']||="leader01"
    ENV['LEADER_IP']||="192.168.9.11"
    ENV['SERVER_COUNT']||="2"
    ENV['DD_API_KEY']||="ONLY REQUIRED FOR DATADOG IMPLEMENTATION"
    
    #global config
    config.vm.synced_folder ".", "/vagrant"
    config.vm.synced_folder ".", "/usr/local/bootstrap"
    config.vm.box = "allthingscloud/web-page-counter"
    #config.vm.box_version = "0.2.1568383863"
    config.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_consul.sh", run: "always"
    # config.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_dd_agent.sh", env: {"DD_API_KEY" => ENV['DD_API_KEY']}

    config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 1
    end

    config.vm.define "leader01" do |leader01|
        leader01.vm.hostname = ENV['LEADER_NAME']
        leader01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh", run: "always"
        leader01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_vault.sh", run: "always"
        leader01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_nomad.sh", run: "always"
        leader01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_SecretID_Factory.sh", run: "always"
        leader01.vm.network "private_network", ip: ENV['LEADER_IP']
        leader01.vm.network "forwarded_port", guest: 4646, host: 8324
        leader01.vm.network "forwarded_port", guest: 8321, host: 8321
        leader01.vm.network "forwarded_port", guest: 8200, host: 8323
        leader01.vm.network "forwarded_port", guest: 8314, host: 8325
    end

    config.vm.define "redis01" do |redis01|
        redis01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_vault.sh", run: "always"
        redis01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh", run: "always"
        redis01.vm.hostname = ENV['REDIS_MASTER_NAME']
        redis01.vm.network "private_network", ip: ENV['REDIS_MASTER_IP']
        redis01.vm.provision :shell, inline: "/usr/local/bootstrap/scripts/install_redis.sh"
    end
    
    (1..3).each do |i|
        config.vm.define "godev0#{i}" do |devsvr|
            devsvr.vm.hostname = "godev0#{i}"
            devsvr.vm.network "private_network", ip: "192.168.9.#{100+i*10}"
            devsvr.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_vault.sh", run: "always"
            devsvr.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh", run: "always"
            devsvr.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_nomad.sh", run: "always"
            devsvr.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_go_app.sh"
        end
    end

    config.vm.define "web01" do |web01|
        web01.vm.hostname = ENV['NGINX_NAME']
        web01.vm.network "private_network", ip: ENV['NGINX_IP']
        web01.vm.network "forwarded_port", guest: ENV['NGINX_GUEST_PORT'], host: ENV['NGINX_HOST_PORT']
        web01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/install_vault.sh", run: "always"
        web01.vm.provision "shell", inline: "/usr/local/bootstrap/scripts/consul_enable_acls_1.4.sh", run: "always"
        web01.vm.provision :shell, inline: "/usr/local/bootstrap/scripts/install_webserver.sh"
        web01.vm.network "forwarded_port", guest: 9091, host: 9091
        web01.vm.network "forwarded_port", guest: 9090, host: 9090
   end

   puts info if ARGV[0] == "status"

end
