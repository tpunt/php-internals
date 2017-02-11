defmodule ArticlesGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router

  @opts Router.init([])

  @doc """
  GET /api/articles
  """
  test "list all articles" do
    conn = conn(:get, "/api/articles", %{})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"articles" => _articles} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/articles
  """
  test "list all articles overview" do
    conn = conn(:get, "/api/articles", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"articles" => _articles} = Poison.decode!(response.resp_body)
  end
end
