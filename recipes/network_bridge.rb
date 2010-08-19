# This creates a network bridge
#
# Warning: Hetzner does not support bridged interfaces, 
# so do not try to add the main interface to the bridge


package 'bridge-utils'

file '/etc/sysctl.d/33-ip-forward.conf' do
  backup false
  action :create
  content "net.ipv4.ip_forward=1\n"
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
end


