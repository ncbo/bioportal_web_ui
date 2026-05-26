# frozen_string_literal: true

module Admin
  module UsersHelper
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def user_datatable_actions(username)
      links = [
        link_to('Detail', "/accounts/#{username}", class: 'mx-1'),
        link_to('Delete', 'javascript:;', class: 'delete-user mx-1', data: { account_name: username }),
        link_to('Login as', login_as_path(username: username), class: 'mx-1')
      ]
      safe_join(links, '|')
    end
  end
end
