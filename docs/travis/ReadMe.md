# CI/CD Pipeline Overview

## Central Repository

Start with a centralised code repository like github, gitlab or bitbucket. These are all based on [Linus Torvalds'](https://en.wikipedia.org/wiki/Linus_Torvalds) open source distributed version control system called git. A good tutorial can be found [here](https://www.atlassian.com/git/tutorials).

When working with groups on code or collaborating on open source github repositories it's a good idea to leverage [github templates](https://blog.github.com/2016-02-17-issue-and-pull-request-templates/) at the start of a project to help standardise the PULL REQUESTS and ISSUE LOGS.

![image](https://user-images.githubusercontent.com/9472095/43801332-b32cada4-9a8a-11e8-8e92-6508498102dc.png)

## Continuous Integration

[Travis-CI](https://travis-ci.org/) has been used to test application changes and deploy releases to github.

![image](https://user-images.githubusercontent.com/9472095/43800289-d151b05c-9a87-11e8-957c-9584e2906951.png)

This is achieved by signing up for a Travis-CI account, linking this to your github account, and then configuring a _**.travis.yml**_ file in the root of the repository.

``` yml
language: go
sudo: required
addons:
  apt:
    packages:
    - lynx
    - jq
    - wget -q
    - grep
    - nginx
go:
- '1.11.5'
before_script:
- sudo rsync -az ${TRAVIS_BUILD_DIR}/ /usr/local/bootstrap/
- pushd packer
- if [ $VAGRANT_CLOUD_TOKEN ] ; then packer validate -syntax-only template.json ; fi
- popd
- cat /usr/local/bootstrap/var.env
- sed -i 's/LEADER_IP=192.168.9.11/LEADER_IP=127.0.0.1/g' /usr/local/bootstrap/var.env
- sed -i 's/REDIS_MASTER_IP=192.168.9.200/REDIS_MASTER_IP=127.0.0.1/g' /usr/local/bootstrap/var.env
- cat /usr/local/bootstrap/var.env
- bash scripts/install_consul.sh
- bash scripts/consul_enable_acls_1.4.sh
- bash scripts/install_vault.sh
- bash scripts/install_redis.sh
- bash scripts/install_nomad.sh
- bash scripts/install_SecretID_Factory.sh
- pwd
- ls -al /usr/local/bootstrap/
- sudo cp /home/travis/.vault-token /usr/local/bootstrap/.vault-token
- echo 314159265359 > /usr/local/bootstrap/.appRoleID
script:
- source /usr/local/bootstrap/var.env
- cat /usr/local/bootstrap/var.env
- sudo VAULT_ADDR=http://127.0.0.1:8200 vault status
# Configure consul environment variables for use with certificates 
- export CONSUL_HTTP_ADDR=https://127.0.0.1:8321
- export CONSUL_CACERT=certificate-config/consul-ca.pem
- export CONSUL_CLIENT_CERT=certificate-config/cli.pem
- export CONSUL_CLIENT_KEY=certificate-config/cli-key.pem
- consul version
- inspec exec test/ImageBuild
- bash scripts/travis_run_go_app.sh
deploy:
  provider: releases
  api_key:
    secure: dAo/pXZ/jan3BcUA2bbhYl2v5QAW2JRAsaM0g077OJYxjUoepWarrb8puk0zdGfZ92ER+a7jwmXudbFVzk22Vp/aliIMkbrouQXVrXQaWZq0H45XD3grC5Pgbjdbn/s7gfCXk6IsZNkc1ztkpluFGox7iZXIYsrWJDvnjMNuhs6KWQpymKD8VQaQU1AqnWOOCWmkqLOy7pXKJHkjhkjHKJHKGFdrTRETReytrytrytrHgftf9XQS44I5KkUibNFc5vxDqZriNCAkVSYZbvhmEphRb2iWGEtTxrJtU61Gj+fVpu6wpEO0JgWZNqmJTXgIXiPYb9i//uuRnA8qVym+PBl2azkMrmRV7TFbyzewhoopsadaisyivejustpublishedakeytogithub/bzLQMjkjhfkjdhfskjdfhksjdhfuytuytuwednbvdnbasaiuyiuy/Nd8OMaJZjjoTNDc8frqQ9j84Q1WYTt1mhkMJF4LjXTar45nomR2GjBWfrETQBCGmO4fKYyNctxDwK96JGtT8vfC4LfhtftTtTO2VqIMZ7lPbHzgyIswSBcVc9B7VIPS4Zka8JEzO1CRzeoL9u6HWNsUnre/U+twyxNmkZ1ZQW1kjeet8PT6S7eVRJuMofQJs0bdEHJFNfwvNg9ySXKs=
  file_glob: true
  file: 
    - "./webcounter"
  skip_cleanup: true
  on:
    repo: allthingsclowd/web_page_counter
    tags: true
```
__Continuous Deployment__

All commits, pull requests and merges automatically envoke a Travis-CI run.
When [Tags](https://help.github.com/articles/working-with-tags/) are applied to the repository Travis-CI also creates a "deployment" by uploading binaries or files from the build server to the githib repository - located under the releases tab.

![image](https://user-images.githubusercontent.com/9472095/43802124-d59ec898-9a8c-11e8-82d3-bad46fb68891.png)

## Chef's Inspec Test Framework

[Inspec tests](https://www.inspec.io/) have now also been added to the travis build process. Some basic tests are included to ensure that the correct binaries are delivered to the host before the application is deployed and tested.

``` ruby
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
   its('stdout') { should match /Consul v1.4.4/ }
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
  describe command('consul-template -version') do
   its('stderr') { should match /v0.20.0/ }
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
  describe command('envconsul -version') do
   its('stderr') { should match /v0.7.3/ }
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
   its('stdout') { should match /v1.1.0/ }
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
   its('stdout') { should match /v0.9.0/ }
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
   its('stdout') { should match /v0.12.0/ }
  end
end

```

See the `test/ImageBuild` for the complete Inspec test profile

[back](../../ReadMe.md)