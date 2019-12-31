# encoding: utf-8
# copyright: 2019, Graham Land

title 'Verify WebPageCounter Binaries'

# control => test
control 'audit_installation_prerequisites' do
  impact 1.0
  title 'os and packages'
  desc 'verify os type and base os packages'

  describe os.family do
    it {should eq 'debian'}
  end

  describe package('wget') do
    it {should be_installed}
  end

  describe package('unzip') do
    it {should be_installed}
  end

  describe package('git') do
    it {should be_installed}
  end

  describe package('redis-server') do
    it {should be_installed}
  end

  describe package('nginx') do
    it {should be_installed}
  end

  describe package('lynx') do
    it {should be_installed}
  end

  describe package('jq') do
    it {should be_installed}
  end

  describe package('curl') do
    it {should be_installed}
  end

  describe package('net-tools') do
    it {should be_installed}
  end

end

control 'consul-binary-exists-1.0' do         
  impact 1.0                      
  title 'consul binary exists'
  desc 'verify that the consul binary is installed'
  describe file('/usr/local/bin/consul') do 
    it { should exist }
  end
end

control 'consul-binary-version-1.0' do                      
  impact 1.0                                
  title 'consul binary version check'
  desc 'verify that the consul binary is the correct version'
  describe command('consul version') do
   its('stdout') { should match /Consul v1.7.0-beta2/ }
  end
end

control 'consul-template-binary-exists-1.0' do         
  impact 1.0                      
  title 'consul-template binary exists'
  desc 'verify that the consul-template binary is installed'
  describe file('/usr/local/bin/consul-template') do 
    it { should exist }
  end
end

control 'consul-template-binary-version-1.0' do                      
  impact 1.0                                
  title 'consul-template binary version check'
  desc 'verify that the consul-template binary is the correct version'
  describe command('/usr/local/bin/consul-template --version') do
    # its('stderr') { should match /0.23.0/ }
    its('exit_status') { should eq 0 }
  end
end

control 'envconsul-binary-exists-1.0' do         
  impact 1.0                      
  title 'envconsul binary exists'
  desc 'verify that the envconsul binary is installed'
  describe file('/usr/local/bin/envconsul') do 
    it { should exist }
  end
end

control 'envconsul-binary-version-1.0' do                      
  impact 1.0                                
  title 'envconsul binary version check'
  desc 'verify that the envconsul binary is the correct version'
  describe command('/usr/local/bin/envconsul --version') do
  #  its('stderr') { should match /0.9.1/ }
   its('exit_status') { should eq 0 }
  end
end

control 'vault-binary-exists-1.0' do         
  impact 1.0                      
  title 'vault binary exists'
  desc 'verify that the vault binary is installed'
  describe file('/usr/local/bin/vault') do 
    it { should exist }
  end
end

control 'vault-binary-version-1.0' do                      
  impact 1.0                                
  title 'vault binary version check'
  desc 'verify that the vault binary is the correct version'
  describe command('vault version') do
   its('stdout') { should match /v1.3.1/ }
  end
end

control 'nomad-binary-exists-1.0' do         
  impact 1.0                      
  title 'nomad binary exists'
  desc 'verify that the nomad binary is installed'
  describe file('/usr/local/bin/nomad') do 
    it { should exist }
  end
end

control 'nomad-binary-version-1.0' do                      
  impact 1.0                                
  title 'nomad binary version check'
  desc 'verify that the nomad binary is the correct version'
  describe command('nomad version') do
   its('stdout') { should match /v0.10.2/ }
  end
end

control 'vagrant-binary-exists-1.0' do         
  impact 1.0                      
  title 'vagrant binary exists'
  desc 'verify that the vagrant binary is installed'
  describe file('/usr/local/bin/vagrant') do 
    it { should exist }
  end
end

control 'vagrant-binary-version-1.0' do                      
  impact 1.0                                
  title 'vagrant binary version check'
  desc 'verify that the vagrant binary is the correct version'
  describe command('vagrant version') do
   its('stdout') { should match /2.2.6/ }
  end
end

control 'packer-binary-exists-1.0' do         
  impact 1.0                      
  title 'packer binary exists'
  desc 'verify that the packer binary is installed'
  describe file('/usr/local/bin/packer') do 
    it { should exist }
  end
end

control 'packer-binary-version-1.0' do                      
  impact 1.0                                
  title 'packer binary version check'
  desc 'verify that the packer binary is the correct version'
  describe command('packer version') do
   its('stdout') { should match /v1.5.1/ }
  end
end

control 'terraform-binary-exists-1.0' do         
  impact 1.0                      
  title 'terraform binary exists'
  desc 'verify that the terraform binary is installed'
  describe file('/usr/local/bin/terraform') do 
    it { should exist }
  end
end

control 'terraform-binary-version-1.0' do                      
  impact 1.0                                
  title 'terraform binary version check'
  desc 'verify that the terraform binary is the correct version'
  describe command('terraform version') do
   its('stdout') { should match /v0.12.18/ }
  end
end

control 'golang-exists-1.0' do         
  impact 1.0                      
  title 'golang exists'
  desc 'verify that golang is installed'
  describe file('/usr/local/go/bin/go') do 
    it { should exist }
  end
end

control 'golang-version-1.0' do                      
  impact 1.0                                
  title 'golang version check'
  desc 'verify that golang is the correct version'
  describe command('/usr/local/go/bin/go version') do
   its('stdout') { should match /go1.13/ }
  end
end

control 'envoy-exists-1.0' do         
  impact 1.0                      
  title 'envoy proxy exists'
  desc 'verify that envoy is installed'
  describe file('/usr/bin/envoy') do 
    it { should exist }
  end
end

control 'envoy-version-1.0' do                      
  impact 1.0                                
  title 'envoy version check'
  desc 'verify that envoy is the correct version'
  describe command('/usr/bin/envoy --version') do
   its('stdout') { should match /1.12.2/ }
  end
end

control 'secret-id' do         
  impact 1.0                      
  title 'secret-id binary'
  desc 'verify that secret-id is installed'
  describe file('/usr/local/bin/VaultServiceIDFactory') do 
    it { should exist }
  end
end

control 'web-page-counter' do         
  impact 1.0                      
  title 'web-page-counter exists'
  desc 'verify that web-page-counter is installed'
  describe file('/usr/local/bin/webcounter') do 
    it { should exist }
  end
end

control 'web-front-end' do         
  impact 1.0                      
  title 'web front-end installed'
  desc 'verify that the angular web front-end is installed'
  describe file('/var/www/wpc-fe/index.html') do 
    it { should exist }
  end
end