defmodule PhpInternals.Api.Auth.AuthController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Auth.GitHub
  alias PhpInternals.Api.Users.User

  def index(conn, %{"provider" => provider}) do
    redirect(conn, external: authorize_url!(provider))
  end

  def logout(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def logout(conn, _params) do
    User.delete_token(conn.user.username)

    conn
    |> send_resp(200, "")
  end

  def callback(conn, %{"provider" => provider, "code" => code}) do
    client = get_token!(provider, code)
    user = get_user!(provider, client)

    if user.name === nil do
      conn
      |> put_status(400)
      |> render(PhpInternals.ErrorView, "error.json", error: "Failed request (#{client.token.other_params["error"]})")
    else
      if User.fetch_user_by_token(client.token.access_token) === nil do
        {:ok, data} = HTTPoison.get("https://api.github.com/user?access_token=#{client.token.access_token}")
        user_data = Poison.decode! data.body

        # safe to do?
        case User.user_exists?(user_data["login"]) do
          {:ok, _user} ->
            User.update_user_token(user_data["login"], client.token.access_token)
          {:error, _status_code, _message} ->
            auth_info = %{access_token: client.token.access_token,
              provider: provider,
              name: user.name,
              username: user_data["login"]}

            User.insert_user(auth_info)
        end
      end

      conn
      |> put_resp_header("location", "http://php-internals.herokuapp.com?access_token=#{client.token.access_token}")
      |> send_resp(301, "")
    end
  end

  def callback(conn, %{"provider" => _provider, "error" => error, "error_description" => error_description}) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Error (#{error}): #{error_description}")
  end

  def callback(conn, %{"provider" => _provider}) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Invalid route")
  end

  defp authorize_url!("github"),   do: GitHub.authorize_url!
  defp authorize_url!(_), do: raise "No matching provider available"

  defp get_token!("github", code),   do: GitHub.get_token!(code: code)
  defp get_token!(_, _), do: raise "No matching provider available"

  defp get_user!("github", client) do
    %{body: user} = OAuth2.Client.get!(client, "/user")
    %{name: user["name"], avatar: user["avatar_url"]}
  end
end
