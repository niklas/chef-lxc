set_unless[:container] = {
  :guest_ips => [],
  :base_directory => '/tmp/containers',
  :default => {
    :domain => "vm.local", 
    :variant => 'minbase',
    :suite => 'lucid',
    :mirror => 'http://localhost:3142/de.archive.ubuntu.com/ubuntu/',
    :ipv4 => {
      :address => '192.168.168.100',
      :mask    => '255.255.255.0',
      :gateway => '192.168.168.1'
    }
  }
}
