# This creates a network bridge
#
# Warning: Hetzner does not support bridged interfaces, 
# so do not try to add the main interface to the bridge


package 'bridge-utils'

file '/etc/sysctl.d/33-ip-forward.conf' do
  backup false
  action :create
  content <<-EOSYS
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.all.proxy_ndp=1
  EOSYS
end

#TODO just notify
execute 'activate IP forwarding' do
  command 'service procps start'
end


if node.attribute?('bridges')
  node['bridges'].each do |bridge, settings|

    bridge_config = "/etc/network/interfaces.#{bridge}"

    template bridge_config do
      source 'interfaces.bridge.erb'
      variables :bridge => bridge, :settings => settings
      action :create
    end

    bash "activate network bridge #{bridge}" do
      # is the interfaces newer
      only_if %Q~test /etc/network/interfaces -ot #{bridge_config}~
      code <<-EOSH
        sed -i.#{bridge}_old '/# BEGIN_#{bridge}/,/# END_#{bridge}/d' /etc/network/interfaces
        cat /etc/network/interfaces.#{bridge} >> /etc/network/interfaces
        /etc/init.d/networking restart
      EOSH
    end

    bash "revert to network configuration before #{bridge} (ping google.de gave no answer in 10s)" do
      not_if %Q~ping -q -w 10 -c 1 google.de~
      code <<-EOSH
        cp /etc/network/interfaces.#{bridge}_old /etc/network/interfaces
        /etc/init.d/networking restart
      EOSH
    end


  end

  template '/etc/network/if-up.d/nat-for-bridges' do
    source 'if-up-nat.erb'
    action :create
    mode '0755'
  end
end

search(:virtual_machines, "host:#{node['fqdn']}").each do |machine|
  if machine.has_key?('ipv6')
    address = machine['ipv6'].sub(%r~/.*$~, '') # remove netmask
    execute "add #{machine['id']} to ipv6 neighborhood" do
      command %Q~ip -6 neigh add proxy #{address} dev eth0~
    end
  end
end
