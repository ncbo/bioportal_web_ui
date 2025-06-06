# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary
# server in each group is considered to be the first
# unless any hosts have the primary property set.
# Don't declare `role :all`, it's a meta role
role :app, %w{ui1.stage.ontoportal.org ui2.stage.ontoportal.org}
role :db, %w{ui1.stage.ontoportal.org} # sufficient to run db:migrate only on one system

# Extended Server Syntax
# ======================
# This can be used to drop a more detailed server
# definition into the server list. The second argument
# something that quacks like a hash can be used to set
# extended properties on the server.
#server 'example.com', user: 'deploy', roles: %w{web app}, my_property: :my_value
set :log_level, :error
# you can set custom ssh options
# it's possible to pass any option but you need to keep in mind that net/ssh understand limited list of options
# you can see them in [net/ssh documentation](http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start)
# set it globally
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
# and/or per server
# server 'example.com',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
# setting per server overrides global ssh_options
set :ssh_options, {
  user: 'deployer',
  forward_agent: 'true',
  keys: %w(config/deploy_id_rsa),
  auth_methods: %w(publickey),
  # use ssh proxy if UI servers are on a private network
  proxy: Net::SSH::Proxy::Command.new('ssh deployer@sshproxy.ontoportal.org -W %h:%p')
}

#private git repo for configuraiton
set :private_config_repo, ENV['PRIVATE_CONFIG_REPO'] || 'git@github.com:your_org/your_private_config_repo.git'
