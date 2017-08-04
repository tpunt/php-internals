defmodule UserGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/users/user1
  """
  test "list an existing user" do
    conn = conn(:get, "/api/users/user1")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"user" => %{"username" => "user1", "name" => "u1", "privilege_level" => 1,
      "bio" => _, "github_url" => _, "email" => _, "avatar_url" => _, "location" => _,
      "blog_url" => _}}
        = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/users/non-existent
  """
  test "list an non-existent user" do
    conn = conn(:get, "/api/users/non-existent")
    response = Router.call(conn, @opts)

    assert response.status === 404
  end

  @doc """
  GET /api/users/non-existent
  """
  test "list a user's contributions" do
    conn = conn(:get, "/api/users/user1/contributions", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"user" => %{"username" => "user1", "name" => "u1", "privilege_level" => 1},
      "contributions" => _c} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/users/non-existent
  """
  test "list a user by their token" do
    conn =
      conn(:get, "/api/user", %{})
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"user" => %{"username" => "user1", "name" => "u1", "privilege_level" => 1,
      "avatar_url" => "~1"}} = Poison.decode!(response.resp_body)
  end
end
