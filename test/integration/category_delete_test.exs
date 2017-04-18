defmodule CategoryDeleteTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  DELETE /api/categories/non-existent
  """
  test "Unauthenticated delete request for a non-existent category" do
    conn = conn(:delete, "/api/categories/non-existent")

    response = Router.call(conn, @opts)

    assert response.status === 401
  end

  @doc """
  DELETE /api/categories/existent
  """
  test "Unauthenticated delete request for an existing category" do
    conn = conn(:delete, "/api/categories/existent")

    response = Router.call(conn, @opts)

    assert response.status === 401
  end

  @doc """
  DELETE /api/categories/non-existent -H 'authorization: at1'
  """
  test "Authorised invalid delete request for a non-existent category" do
    conn =
      conn(:delete, "/api/categories/non-existent")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 404
  end

  @doc """
  DELETE /api/categories/existent -H 'authorization: at1'
  """
  test "Authorised delete request for an existing category" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}'})")

    conn =
      conn(:delete, "/api/categories/#{name}")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)<-[:DELETE]-(:User {access_token: 'at1'})
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'})-[r]-()
      DELETE r, c
    """)
  end

  @doc """
  DELETE /api/categories/non-existent -H 'authorization: at2'
  """
  test "Authorised soft delete for a non-existent category" do
    conn =
      conn(:delete, "/api/categories/non-existent")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 404
  end

  @doc """
  DELETE /api/categories/existent -H 'authorization: at2'
  """
  test "Authorised delete for a category" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}'})")

    conn =
      conn(:delete, "/api/categories/#{name}")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 204
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:CategoryDeleted {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'delete'}]->(:User {access_token: 'at2'})
      RETURN c
    """)

    response = Router.call(conn(:get, "/api/categories/#{name}", %{}), @opts)

    assert response.status === 404

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:CategoryDeleted {name: '#{name}'})-[r]-()
      DELETE r, c
    """)
  end

  @doc """
  DELETE /api/categories/existent -H 'authorization: at2'
  """
  test "Authorised invalid delete for a category (still linked article)" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (a:Article {url: 'existent'})
      CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}'}),
        (a)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/categories/#{name}")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "A category cannot be deleted whilst linked to symbols or articles"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'})-[r]-()
      DELETE r, c
    """)
  end

  @doc """
  DELETE /api/categories/... -H 'authorization: ...'
  """
  test "Authorised invalid attempt at deleting a category (patch limit reached)" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (user:User {username: '#{name}', access_token: '#{name}', privilege_level: 1}),
        (c:UpdateCategoryPatch)
      FOREACH (ignored in RANGE(1, 20) |
        CREATE (c)-[:CONTRIBUTOR]->(user)
      )
    """)

    conn =
      conn(:delete, "/api/categories/...")
      |> put_req_header("authorization", "#{name}")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The maximum patch limit (20) has been exceeded!"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {username: '#{name}'})<-[r]-(c) DELETE r, u, c")
  end

  @doc """
  DELETE /api/categories/existent -H 'authorization: at1'
  """
  test "Authorised invalid delete request a category with a delete patch" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at1'})
      CREATE (c:Category {url: '#{name}'}),
        (c)<-[:DELETE]-(u)
    """)

    conn =
      conn(:delete, "/api/categories/#{name}")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The specified category already has a delete patch"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: '#{name}'})-[r]-()
      DELETE r, c
    """)
  end
end
