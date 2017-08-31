defmodule PhpInternals.Api.Contributions.ContributionController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Utilities
  alias PhpInternals.Api.Contributions.Contribution
  alias PhpInternals.Api.Users.User

  def index(conn, %{"view" => "overview", "author" => username}) do
    with {:ok, _username} <- User.valid?(username) do
      send_resp(conn, 200, Contribution.fetch_all_overview_for_cache(username))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def index(conn, %{"view" => "overview"} = params) do
    with {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
      send_resp(conn, 200, Contribution.fetch_all_overview_cache(offset, limit))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def index(conn, %{"author" => username} = params) do
    if !params["view"] || params["view"] === "normal" do
      with {:ok, _username} <- User.valid?(username),
           {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
           {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
        send_resp(conn, 200, Contribution.fetch_all_normal_for_cache(username, offset, limit))
      else
        {:error, status_code, error} ->
          conn
          |> put_status(status_code)
          |> render(PhpInternals.ErrorView, "error.json", error: error)
      end
    else
      conn
      |> put_status(400)
      |> render(PhpInternals.ErrorView, "error.json", error: "Invalid view parameter given")
    end
  end

  def index(conn, params) do
    if !params["view"] || params["view"] === "normal" do
      with {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
           {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
        send_resp(conn, 200, Contribution.fetch_all_normal_cache(offset, limit))
      else
        {:error, status_code, error} ->
          conn
          |> put_status(status_code)
          |> render(PhpInternals.ErrorView, "error.json", error: error)
      end
    else
      conn
      |> put_status(400)
      |> render(PhpInternals.ErrorView, "error.json", error: "Invalid view parameter given")
    end
  end
end
