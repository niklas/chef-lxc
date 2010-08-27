#
# Cookbook Name:: lxc
# Recipe:: default
#
# Copyright 2010, Company
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


package 'debootstrap'
package 'apt-cacher-ng'
package 'inotify-tools'

include_recipe 'lxc::manage'
include_recipe 'lxc::network_bridge'
include_recipe 'lxc::dns'

host = node[:container]

machines = search(:virtual_machines, "host:#{node['fqdn']}")

directory host[:base_directory] do
  action :create
  mode '0755'
  owner 'root'
  group 'root'
end

template host[:base_directory] / 'main.conf' do
  source 'tools/main.conf.erb'
  mode '0644'
  owner 'root'
  group 'root'
  variables :machines => machines
end

template '/usr/bin/lxc-shutdown-agent' do
  source 'tools/lxc-shutdown-agent.erb'
  mode '0755'
  owner 'root'
  group 'root'
end


template '/usr/bin/lxc-start-vm' do
  source 'tools/lxc-start-vm.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-stop-vm' do
  source 'tools/lxc-stop-vm.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-start-all' do
  source 'tools/lxc-start-all.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-shutdown-all' do
  source 'tools/lxc-shutdown-all.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-status-all' do
  source 'tools/lxc-status-all.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-kill-all' do
  source 'tools/lxc-kill-all.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/etc/init/lxc.conf' do
  source 'init-lxc.conf.erb'
  mode '0644'
  owner 'root'
  group 'root'
end

# Followed instruction from
# http://blog.bodhizazen.net/linux/lxc-configure-ubuntu-lucid-containers/

machines.each do |guest|
  # Bootstrap
  domain = guest[:domain] || host[:default][:domain]
  hostname = "#{guest[:id]}.#{domain}"

  variant = guest[:variant] ||= host[:default][:variant]
  suite   = guest[:suite  ] ||= host[:default][:suite  ]
  mirror  = guest[:mirror ] ||= host[:default][:mirror ]
  packages= guest[:packages] ||= host[:default][:packages]
  guest[:ipv4] ||= host[:default][:ipv4]

  home = host[:base_directory] / guest[:id]
  rootfs  =  home / 'rootfs'

  execute "debootstrap" do
    command "debootstrap --variant=#{variant} --include #{packages.join(',')} #{suite} #{rootfs} #{mirror}"
    action :run
    not_if "test -f #{rootfs / 'etc' / 'issue'}"
  end

  template home / 'config' do
    source "lxc.conf.erb"
    variables :host => host, :guest => guest, :home => home, :rootfs => rootfs, :hostname => hostname
    action :create
  end

  template home / 'fstab' do
    source 'fstab.erb'
    variables :host => host, :guest => guest, :rootfs => rootfs, :hostname => hostname
    action :create
  end

  file rootfs / 'etc' / 'inittab' do
    action :delete
  end

  file rootfs / 'etc' / 'hostname' do
    backup false
    content hostname
    action :create
  end

  file rootfs / 'etc' / 'hosts' do
    backup false
    action :create
    content %Q~127.0.0.1 #{hostname} #{guest[:id]} localhost\n~
  end

  template rootfs / 'etc' / 'apt' / 'sources.list' do
    source 'rootfs/sources.list.erb'
    variables :host => host, :guest => guest
  end

  bash 'remove as many init scripts as possible' do
    only_if %Q~test -f #{rootfs}/etc/init/hwclock.conf~
    code <<-EOSH
      rm #{rootfs}/etc/init/{hwclock,mount,plymouth,udev,network,tty5,tty6}*
      true
    EOSH
  end

  bash 'remove pointless services' do
    only_if %Q'test -f #{rootfs}/etc/rc0.d/S*umountfs'
    code <<-EOSH
      chroot #{rootfs} /usr/sbin/update-rc.d -f umountfs remove
      chroot #{rootfs} /usr/sbin/update-rc.d -f hwclock.sh remove
      chroot #{rootfs} /usr/sbin/update-rc.d -f hwclockfirst.sh remove
      chroot #{rootfs} /usr/sbin/update-rc.d -f umountroot remove
      chroot #{rootfs} /usr/sbin/update-rc.d -f ondemand remove
    EOSH
  end

  template rootfs / 'etc' / 'init' / 'vm.conf' do
    source 'rootfs/init-vm.conf.erb'
    action :create
  end

  template rootfs / 'etc' / 'init' / 'vm-net.conf' do
    source 'rootfs/init-net.conf.erb'
    variables :host => node, :guest => guest
  end

  template rootfs / 'etc' / 'init' / 'vm-power.conf' do
    source 'rootfs/vm-power.conf.erb'
    variables :host => node
  end

  template rootfs / 'usr' / 'sbin' / 'install-chef.sh' do
    source 'rootfs/install-chef.sh.erb'
    variables :host => host, :guest => guest
    mode '0755'
  end

  template rootfs / 'etc' / 'init' / 'chef-install.conf' do
    source 'rootfs/chef-install.conf.erb'
    variables :host => host, :guest => guest
  end

  directory rootfs / 'etc' / 'chef' do
    action :create
    owner 'chef'
    group 'chef'
    mode '0755'
  end

  chef_private_key = rootfs / 'etc' / 'chef' / 'client.pem'
  chef_archived_key = home / "chef-client.pem"
  execute "register vm at chef server" do
    command %Q~knife client -u #{node[:fqdn]} -k /etc/chef/client.pem --no-editor create #{hostname} -f #{chef_archived_key}~
    action :run
    not_if "test -f #{chef_archived_key}"
  end

  execute "archive chef private key" do
    command %Q~cp #{chef_private_key} #{chef_archived_key}~
    action :run
    not_if "test -f #{chef_archived_key}"
    only_if "test -f #{chef_private_key}"
  end

  execute "restore chef private key" do
    command %Q~cp #{chef_archived_key} #{chef_private_key}~
    action :run
    only_if "test -f #{chef_archived_key}"
    not_if "test -f #{chef_private_key}"
  end

  # this only has to be done in ubuntu
  # If you want to read this, you will need popcorn!
  # https://bugs.launchpad.net/ubuntu/+source/gems/+bug/145267
  execute "add rubygems executable directory to environment" do
    bad_bin = "/var/lib/gems/1.8/bin"
    not_if "grep ':#{bad_bin}' #{rootfs}/etc/environment"
    command %Q~sed -i.rubygems 's#"$#:#{bad_bin}"#' #{rootfs}/etc/environment~
  end


  ssh_dir = home / 'ssh'
  execute "restore ssh host keys" do
    only_if "test -d #{ssh_dir}"
    command %Q~cp #{ssh_dir}/* #{rootfs}/etc/ssh/~
  end

  bash "archive ssh host keys" do
    not_if "test -d #{ssh_dir}"
    code %Q~mkdir -p #{ssh_dir} && cp #{rootfs}/etc/ssh/ssh_host_{r,d}sa_key{,.pub} #{ssh_dir}/~
  end

end
