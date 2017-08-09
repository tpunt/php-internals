defmodule ContributionsGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/users
  """
  test "list all contributions" do
    conn = conn(:get, "/api/contributions", %{})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"total_contributions" => _, "contributions" => _, "meta" => %{}}
      = Poison.decode!(response.resp_body)
  end
end
