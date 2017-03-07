defmodule PhpInternals.Api.Users.UserController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Users.User
  alias PhpInternals.Utilities

  def index(%{user: %{privilege_level: 3}} = conn, _params) do
    conn
    |> put_status(200)
    |> render("index.json", users: User.fetch_all)
  end

  def index(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def index(conn, _params) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def show_contributions(conn, %{"username" => username} = params) do
    with {:ok, user} <- User.valid?(username),
         {:ok, order_by} <- User.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
      contributions = User.fetch_contributions_for(username, order_by, ordering, offset, limit)

      conn
      |> put_status(200)
      |> render("show_contributions.json", %{user: user, contributions: contributions})
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"username" => username}) do
    with {:ok, user} <- User.valid?(username) do
      conn
      |> put_status(200)
      |> render("show_full.json", user: user)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
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
