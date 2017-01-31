defmodule PhpInternals.Api.Docs.TypeController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Docs.Type

  def index(conn, %{}) do
    types = Type.fetch_all_types
    render(conn, "index.json", types: types)
  end
end
