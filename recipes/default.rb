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

include_recipe 'lxc::manage'
include_recipe 'lxc::network_bridge'

host = node[:container]

directory host[:base_directory] do
  action :create
  mode 0755
  owner 'root'
  group 'root'
end


# Followed instruction from
# http://blog.bodhizazen.net/linux/lxc-configure-ubuntu-lucid-containers/

search(:virtual_machines) do |guest|
  # Bootstrap
  domain = guest[:domain] || host[:default][:domain]
  hostname = "#{guest[:id]}.#{domain}"

  variant = guest[:variant] ||= host[:default][:variant]
  suite   = guest[:suite  ] ||= host[:default][:suite  ]
  mirror  = guest[:mirror ] ||= host[:default][:mirror ]
  packages= guest[:packages] ||= host[:default][:packages]
  guest[:ipv4] ||= host[:default][:ipv4]
  rootfs  = host[:base_directory] / hostname + '.rootfs'

  execute "debootstrap" do
    command "debootstrap --variant=#{variant} --include #{packages.join(',')} #{suite} #{rootfs} #{mirror}"
    action :run
    not_if "test -f #{rootfs / 'etc' / 'issue'}"
  end

  template host[:base_directory] / hostname + '.lxc.conf' do
    source "lxc.conf.erb"
    variables :host => host, :guest => guest, :rootfs => rootfs, :hostname => hostname
    action :create
  end

  template host[:base_directory] / hostname + '.fstab' do
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

  template rootfs / 'etc' / 'apt' / 'sources.list' do
    source 'rootfs/sources.list.erb'
    variables :host => host, :guest => guest
  end

  bash 'remove as many init scripts as possible' do
    only_if %Q~test -f #{rootfs}/etc/init/hwclock.conf~
    code <<-EOSH
      rm #{rootfs}/etc/init/{hwclock,mount,plymouth,udev,network}*
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
    variables :host => node
  end

  template rootfs / 'etc' / 'init' / 'chef-install.conf' do
    source 'rootfs/chef-install.conf.erb'
    variables :host => host, :guest => guest
  end
end
