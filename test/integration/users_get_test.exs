defmodule UsersGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

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

  @doc """
  GET /api/users?search=eR1
  """
  test "search all users by username" do
    conn = conn(:get, "/api/users", %{"search" => "eR1"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"users" => users} = Poison.decode!(response.resp_body)
    assert %{"user" => %{"username" => "user1"}} = List.first users
  end

  @doc """
  GET /api/users?search==eR1
  """
  test "search all users by exact username" do
    conn = conn(:get, "/api/users", %{"search" => "=useR1"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"users" => users} = Poison.decode!(response.resp_body)
    assert %{"user" => %{"username" => "user1"}} = List.first users
  end

  @doc """
  GET /api/users?search==useR
  """
  test "search all users by exact username (no results)" do
    conn = conn(:get, "/api/users", %{"search" => "=useR"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"users" => []} = Poison.decode!(response.resp_body)
  end
end
