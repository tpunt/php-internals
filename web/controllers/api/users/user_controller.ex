defmodule PhpInternals.Api.Users.UserController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Users.User
  alias PhpInternals.Utilities
  alias PhpInternals.Stats.Counter

  def index(conn, params) do
    with {:ok, order_by} <- User.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
      Counter.exec(["incr", "visits:users"])
      send_resp(conn, 200, User.fetch_all_cache(order_by, ordering, offset, limit, params["search"]))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"username" => username}) do
    with {:ok, user} <- User.valid?(username) do
      Counter.exec(["incr", "visits:users:#{username}"])
      send_resp(conn, 200, user)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def self(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(404)
    |> render(PhpInternals.ErrorView, "error.json", error: "User not found")
  end

  def self(%{user: user} = conn, _params) do
    user_data = %{"user" => %{"username" => user.username, "name" => user.name,
      "privilege_level" => user.privilege_level, "avatar_url" => user.avatar_url}}

    conn
    |> put_status(200)
    |> render("show_overview.json", user: user_data)
  end

  def update(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: %{privilege_level: pl}} = conn, %{"username" => username, "user" => %{} = user}) do
    with {:ok} <- User.contains_only_expected_fields?(pl, user),
         {:ok, _user_old} <- User.valid?(username) do
      if pl !== 3 and conn.user.username !== username do
        conn
        |> put_status(400)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorized attempt at updating another user")
      else
        conn
        |> put_status(200)
        |> render("show_full.json", user: User.update(username, user))
      end
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def update(conn, _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Malformed request data")
  end
end
