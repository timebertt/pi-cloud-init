VM_NAME = "raspios-builder"

Vagrant.configure("2") do |config|
  config.vm.box = "debian/buster64"
  
  config.vm.define VM_NAME
  config.vm.hostname = VM_NAME

  config.vm.provider "virtualbox" do |v|
    v.cpus = 8
    v.memory = 16000
    v.name = VM_NAME
  end

  config.vm.provision "shell", path: "bootstrap.sh"

  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder ".", "/home/vagrant/pi-cloud-init", type: "rsync", rsync__auto: true, rsync__exclude: ['*.zip', '*.img']
end
