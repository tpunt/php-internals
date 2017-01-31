defmodule CategoryDeleteTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  DELETE /api/docs/categories/non-existent
  """
  test "Unauthenticated soft delete request for a non-existent category" do
    conn = conn(:delete, "/api/docs/categories/non-existent")

    response = Router.call(conn, @opts)

    assert response.status == 401
  end

  @doc """
  DELETE /api/docs/categories/existent
  """
  test "Unauthenticated soft delete request for an existing category" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}'})")

    conn = conn(:delete, "/api/docs/categories/#{name}")

    response = Router.call(conn, @opts)

    assert response.status == 401
  end

  @doc """
  DELETE /api/docs/categories/non-existent -H 'authorization: at1'
  """
  test "Authorised soft delete request for a non-existent category" do
    conn =
      conn(:delete, "/api/docs/categories/non-existent")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 404
  end

  @doc """
  DELETE /api/docs/categories/existent -H 'authorization: at1'
  """
  test "Authorised soft delete request for an existing category" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}'})")

    conn =
      conn(:delete, "/api/docs/categories/#{name}")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 202
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c1:Category {name: '#{name}'})-[:DELETE]->(c2:DeleteCategoryPatch) RETURN c2")

    Neo4j.query!(Neo4j.conn, "MATCH (c1:Category {name: '#{name}'})-[r:DELETE]->(c2:DeleteCategoryPatch) DELETE r, c1, c2")
  end

  @doc """
  DELETE /api/docs/categories/non-existent -H 'authorization: at2'
  """
  test "Authorised soft delete for a non-existent category" do
    conn =
      conn(:delete, "/api/docs/categories/non-existent")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 404
  end

  @doc """
  DELETE /api/docs/categories/existent -H 'authorization: at2'
  """
  test "Authorised soft delete for a category" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}'})")

    conn =
      conn(:delete, "/api/docs/categories/#{name}")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 204

    conn = conn(:get, "/api/docs/categories/#{name}")

    response = Router.call(conn, @opts)

    assert response.status == 404
  end

  @doc """
  DELETE /api/docs/categories/non-existent -H 'authorization: at2'
  """
  test "Unauthenticated hard delete for a non-existent category" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{name}', introduction: '...', url: '#{name}'})")

    conn =
      conn(:delete, "/api/docs/categories/#{name}")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 204

    conn = conn(:get, "/api/docs/categories/#{name}")

    response = Router.call(conn, @opts)

    assert response.status == 404
  end
end
