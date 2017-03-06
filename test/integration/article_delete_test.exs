defmodule ArticleDeleteTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  DELETE /api/articles/:aricle_url
  """
  test "Unauthenticated delete for an existing article" do
    conn = conn(:delete, "/api/articles/existent")
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  DELETE /api/articles/existent -H authorization: at3
  """
  test "Authorised invalid delete for a non-existent article" do
    conn =
      conn(:delete, "/api/articles/non-existent")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Article not found"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  DELETE /api/articles/existent -H authorization: at3
  """
  test "Authorised delete for an existing article" do
    art_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3}), (c:Category {url: 'existent'})
      CREATE (a:Article {
          title: '#{art_name}',
          url: '#{art_name}',
          excerpt: '.',
          body: '...',
          date: timestamp(),
          series_name: '',
          series_url: ''
        }),
        (a)-[:AUTHOR]->(u),
        (a)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:delete, "/api/articles/#{art_name}")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 204
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3}),
        (c:Category {url: 'existent'}),
        (ad:ArticleDeleted {url: '#{art_name}'}),
        (ad)-[:AUTHOR]->(u),
        (ad)-[:CATEGORY]->(c)
      RETURN ad
    """)

    Neo4j.query!(Neo4j.conn, "MATCH (a:ArticleDeleted {title: '#{art_name}'})-[r]-() DELETE r, a")
  end
end