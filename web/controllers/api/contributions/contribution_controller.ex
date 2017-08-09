defmodule PhpInternals.Api.Contributions.ContributionController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Utilities
  alias PhpInternals.Api.Contributions.Contribution

  def index(conn, params) do
    with {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
      render(conn, "index.json", contributions: Contribution.fetch_all_cache(offset, limit)["result"])
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end
end
