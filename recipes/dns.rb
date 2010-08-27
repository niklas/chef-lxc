
template '/etc/lxc-hosts.zone' do
  source 'lxc-hosts.zone.erb'
  variables :hosts => search(:virtual_machines)
  action :create
  mode '0644'
end
