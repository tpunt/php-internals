defmodule PhpInternals.Auth.ConnAuth do
  alias PhpInternals.Api.Users.User

  def init(default), do: default

  def call(conn, _opts) do
    auth_header = Enum.find(conn.req_headers, nil, fn {header, _value} ->
      header === "authorization"
    end)

    {privilege_level, username, name, avatar_url} =
      case auth_header do
        nil -> {0, "", "", ""}
        {_header, token} ->
          case User.fetch_by_token(token) do
            nil -> {0, "", "", ""}
            %{"user" => u} -> {u["privilege_level"], u["username"], u["name"], u["avatar_url"]}
          end
      end

    conn
    |> Map.put(:user, %{privilege_level: privilege_level, username: username, name: name, avatar_url: avatar_url})
  end
end
