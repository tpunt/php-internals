defmodule UsersGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router

  @opts Router.init([])

  @doc """
  GET /api/users
  """
  test "list an existing user" do
    conn =
      conn(:get, "/api/users", %{})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"users" => users} = Poison.decode!(response.resp_body)
    assert %{"user" => _} = List.first users
  end
end
