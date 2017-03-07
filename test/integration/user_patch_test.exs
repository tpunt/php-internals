defmodule UserPatchTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  PATCH /api/users/existent
  """
  test "update an existing user" do
    user_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:User {
          id: #{user_id},
          username: '#{user_id}',
          privilege_level: 1,
          access_token: '#{user_id}',
          name: '.',
          avatar_url: '.',
          blog_url: '.',
          github_url: '.',
          email: '.',
          bio: '.',
          location: '.'
      })
    """)

    data = %{"user" => %{"name" => "..","avatar_url" => "..", "blog_url" => "..",
      "github_url" => "..", "email" => "..", "bio" => "..", "location" => ".."}}

    conn =
      conn(:patch, "/api/users/#{user_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "#{user_id}")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"user" => %{"name" => "..","avatar_url" => "..", "blog_url" => "..",
      "github_url" => "..", "email" => "..", "bio" => "..", "location" => ".."}}
        = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {id: #{user_id}}) DELETE u")
  end

  @doc """
  PATCH /api/users/existent
  """
  test "invalid update an existing user (unknow fields given)" do
    data = %{"user" => %{"name" => "..","avatar_url" => "..", "blog_url" => "..",
      "github_url" => "..", "email" => "..", "bio" => "..", "location" => "..",
      "privilege_level" => 3}}

    conn =
      conn(:patch, "/api/users/user1", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Unknown fields given (expecting: name, avatar_url, blog_url, email, bio, location, github_url)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/users/existent
  """
  test "invalid update an existing user (updating someone else without privileges)" do
    data = %{"user" => %{"name" => "..","avatar_url" => "..", "blog_url" => "..",
      "github_url" => "..", "email" => "..", "bio" => "..", "location" => ".."}}

    conn =
      conn(:patch, "/api/users/user3", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Unauthorized attempt at updating another user"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/users/existent
  """
  test "update an existing user (updating someone else with privileges)" do
    user_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (:User {
          id: #{user_id},
          username: '#{user_id}',
          privilege_level: 1,
          access_token: '#{user_id}',
          name: '.',
          avatar_url: '.',
          blog_url: '.',
          github_url: '.',
          email: '.',
          bio: '.',
          location: '.'
      })
    """)

    data = %{"user" => %{"name" => "..","avatar_url" => "..", "blog_url" => "..",
      "github_url" => "..", "email" => "..", "bio" => "..", "location" => "..",
      "privilege_level" => 2}}

    conn =
      conn(:patch, "/api/users/#{user_id}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"user" => %{"name" => "..","avatar_url" => "..", "blog_url" => "..",
      "github_url" => "..", "email" => "..", "bio" => "..", "location" => "..",
      "privilege_level" => 2}} = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {id: #{user_id}}) DELETE u")
  end
end
