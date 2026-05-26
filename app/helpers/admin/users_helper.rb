module Admin::UsersHelper

  def user_datatable_row(user)
    username = user['username'].to_s
    user_id = user['@id'].to_s

    [
      h(user['firstName']),
      h(user['lastName']),
      h(username),
      h(user['email']),
      h(Array(user['role']).join(', ')),
      link_to(user_id, user_id),
      h(user['created']),
      user_datatable_actions(username)
    ]
  end

  def user_datatable_actions(username)
    safe_join([
      link_to('Detail', "/accounts/#{username}", class: 'mx-1'),
      link_to('Delete', 'javascript:;', class: 'delete-user mx-1', data: { account_name: username }),
      link_to('Login as', login_as_path(username: username), class: 'mx-1')
    ], '|')
  end

end
