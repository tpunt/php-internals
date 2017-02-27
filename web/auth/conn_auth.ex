defmodule PhpInternals.Auth.ConnAuth do
  alias PhpInternals.Api.Users.User

  def init(default), do: default

  def call(conn, _opts) do
    auth_header = Enum.find(conn.req_headers, nil, fn {header, _value} ->
      header === "authorization"
    end)

    user_data =
      if auth_header == nil do
        {0, "", ""}
      else
        {_header, token} = auth_header
        user = User.fetch_by_token(token)

        if user === nil do
          {0, "", ""}
        else
          {user["user"]["privilege_level"], user["user"]["username"], user["user"]["name"]}
        end
      end

    {privilege_level, username, name} = user_data

    insert_user = %{privilege_level: privilege_level, username: username, name: name}

    Map.put(conn, :user, insert_user)
  end
end
