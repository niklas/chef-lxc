set_unless[:container] = {
  :guest_ips => [],
  :base_directory => '/tmp/containers',
  :default => {
    :domain => "vm.local", 
    :variant => 'minbase',
    :suite => 'lucid',
    :mirror => ''
  }
}
