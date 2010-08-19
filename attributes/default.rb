set_unless[:container] = {
  :base_directory => '/tmp/containers',
  :default => {
    :domain => "vm.local", 
    :variant => 'minbase',
    :suite => 'lucid',
    :mirror => "http://#{node[:fqdn]}:3142/de.archive.ubuntu.com/ubuntu/",
    :packages => %w(ifupdown locales netbase net-tools iproute openssh-server console-setup iputils-ping wget gnupg ethtool),
    :ipv4 => {
      :cidr => '192.168.168.100/24'
    }
  }
}

# ipv4.address will be used as gateway for guest
set_unless[:bridges] = {
  :vmbr0 => {
    :ipv4 => {
      :address  => '192.168.168.1',
      :netmask  => '255.255.255.0',
      :broadcast => '192.168.168.255'
    }
  }
}
