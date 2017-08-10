defmodule PhpInternals.Api.Contributions.ContributionController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Utilities
  alias PhpInternals.Api.Contributions.Contribution
  alias PhpInternals.Api.Users.User

  def index(conn, %{"view" => "overview", "author" => username}) do
    with {:ok, _username} <- User.valid?(username) do
      contributions = Contribution.fetch_all_overview_for(username)
      render(conn, "index_overview_for_user.json", contributions: contributions)
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
      contributions = Contribution.fetch_all_overview(offset, limit)
      render(conn, "index_overview.json", contributions: contributions["result"])
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
        contributions = Contribution.fetch_all_normal_for(username, offset, limit)
        render(conn, "index_normal_for_user.json", contributions: contributions["result"])
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
        contributions = Contribution.fetch_all_normal(offset, limit)
        render(conn, "index_normal.json", contributions: contributions["result"])
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
