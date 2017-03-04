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

# IO.inspect contributions
      conn
      |> put_status(200)
      |> render("show_contributions.json", %{user: user, contributions: contributions})
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
        IO.inspect conn
    end
  end

  def show(conn, %{"username" => username}) do
    with {:ok, user} <- User.valid?(username) do
      conn
      |> put_status(200)
      |> render("show.json", user: user)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def self(%{user: user} = conn, _params) do
    user_data = %{"user" => %{"username" => user.username, "name" => user.name,
      "privilege_level" => user.privilege_level}}

    conn
    |> put_status(200)
    |> render("show.json", user: user_data)
  end

  def update(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: %{privilege_level: 3}} = conn, %{"username" => username, "user" => %{} = user}) do
    with {:ok} <- User.valid_params?(user),
         {:ok, _user_old} <- User.valid?(username) do
      conn
      |> put_status(200)
      |> render("show.json", user: User.update(username, user))
   else
     {:error, status_code, error} ->
       conn
       |> put_status(status_code)
       |> render(PhpInternals.ErrorView, "error.json", error: error)
   end
  end

  def update(conn, %{"username" => username, "user" => %{} = user}) do
    with {:ok} <- User.valid_params?(user) do
      if conn.user.username !== username do
        conn
        |> put_status(400)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorized attempt at updating another user")
      else
        if Map.has_key?(user, "privilege_level") and conn.user.privilege_level !== user["privilege_level"] do
          conn
          |> put_status(400)
          |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorized attempt at privilege level escalation")
        else
          conn
          |> put_status(200)
          |> render("show.json", user: User.update(username, user))
        end
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
