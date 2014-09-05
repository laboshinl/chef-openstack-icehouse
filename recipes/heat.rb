#
# Cookbook Name:: centos-cloud
# Recipe:: heat
#
# Copyright 2013, cloudtechlab
#
# All rights reserved - Do Not Redistribute
#
include_recipe "selinux::disabled"
include_recipe "centos_cloud::repos"
include_recipe "centos_cloud::mysql"
include_recipe "centos_cloud::iptables-policy"
include_recipe "libcloud"

%w[openstack-heat-api openstack-heat-api-cfn openstack-heat-api-cloudwatch
openstack-heat-common openstack-heat-engine openstack-heat-templates python-heatclient].each do |pkg|
  package pkg do
    action :install
  end
end

libcloud_ssh_keys "openstack" do
  data_bag "ssh_keypairs"
  action [:create, :add]
end

simple_iptables_rule "heat" do
  rule "-p tcp -m multiport --dports 8000,8003"
  jump "ACCEPT"
end

centos_cloud_database "heat" do
  password node[:creds][:mysql_password]
end

centos_cloud_config "/etc/heat/heat.conf" do
  command ["DEFAULT sql_connection mysql://heat:#{node[:creds][:mysql_password]}@localhost/heat",
    "DEFAULT heat_metadata_server_url http://#{node[:ip][:heat]}:8000",
    "DEFAULT heat_waitcondition_server_url http://#{node[:ip][:heat]}:8000/v1/waitcondition",
    "DEFAULT heat_watch_server_url http://#{node[:ip][:heat]}:8003",
    "DEFAULT rpc_backend cinder.openstack.common.rpc.impl_kombu",
    "DEFAULT rabbit_host #{node[:ip][:rabbitmq]}",
    "DEFAULT rabbit_password #{node[:creds][:rabbitmq_password]}",
    "keystone_authtoken service_host #{node[:ip][:keystone]}",
    "keystone_authtoken auth_host #{node[:ip][:keystone]}",
    "keystone_authtoken auth_uri http://#{node[:ip][:keystone]}:35357/v2.0",
    "keystone_authtoken admin_tenant_name admin",
    "keystone_authtoken admin_user admin",
    "keystone_authtoken admin_password #{node[:creds][:admin_password]}"]
end

execute "heat-manage db_sync"

%w[openstack-heat-api openstack-heat-api-cfn
openstack-heat-api-cloudwatch openstack-heat-engine].each do |srv|
  service srv do
    action [:enable, :restart]
  end
end
