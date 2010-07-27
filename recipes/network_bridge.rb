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

execute 'activate IP forwarding' do
  command 'service procps start'
end

template '/etc/network/interfaces.vmbr0' do
  source 'interfaces.vmbr0.erb'
  variables :node => node
  action :create
end

# TODO append to interfaces if neccessary

bash 'activate network bridge' do
  # interfaces older than .vmbr0 ?
  only_if %Q~test /etc/network/interfaces -ot /etc/network/interfaces.vmbr0~
  code <<-EOSH
    sed -i.vmbr0_old '/# BEGIN_vmbr0/,/# END_vmbr0/d' /etc/network/interfaces
    cat /etc/network/interfaces.vmbr0 >> /etc/network/interfaces
  EOSH
end



