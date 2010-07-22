directory '/cgroup' do
  action :create
  mode 0755
  owner 'root'
  group 'root'
end

bash 'add-cgroup-to-fstab' do
  code   %Q~echo "none /cgroup cgroup defaults 0 0" >> /etc/fstab~
  not_if %Q~grep cgroup /etc/fstab~
end


bash 'mount-cgroup' do
  code   %Q~mount /cgroup~
  not_if %Q~mount | grep cgroup~
end

