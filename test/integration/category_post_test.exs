defmodule CategoryPostTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  POST /api/categories/existent -H 'authorization: at2'
  """
  test "[Authorised] [insert] [new subcategory] (without subcategories)" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/categories/existent", %{"category" => %{"name": "#{name}", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at2'}),
        (:Category {name: 'existent'})-[:SUBCATEGORY]->(c)
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'})-[r]-() DELETE r, c")
  end

  @doc """
  POST /api/categories/existent -H 'authorization: at3'
  """
  test "[Authorised] [insert] [new subcategory] (with subcategories)" do
    name = :rand.uniform(100_000_000)
    data = %{"category" => %{"name": "#{name}", "introduction": "...", "subcategories": ["existent"]}}
    conn =
      conn(:post, "/api/categories/existent", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{name}'}),
        (c)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (c2:Category {name: 'existent'})-[:SUBCATEGORY]->(c),
        (c)-[:SUBCATEGORY]->(c2)
      RETURN c
    """)

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'})-[r]-() DELETE r, c")
  end
end
