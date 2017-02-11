defmodule ArticleGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  GET /api/articles/:aricle_url
  """
  test "list an existing article" do
    art_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3}), (c:Category {url: 'existent'})
      CREATE (a:Article {title: '#{art_name}', url: '#{art_name}', excerpt: '.', body: '...', date: timestamp()}),
        (a)-[:AUTHOR]->(u),
        (a)-[:CATEGORY]->(c)
    """)
    conn = conn(:get, "/api/articles/#{art_name}")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"article" =>
      %{"title" => art_name2a, "url" => art_name2b, "excerpt" => ".", "body" => "...", "date" => _date}}
        = Poison.decode!(response.resp_body)
    assert String.to_integer(art_name2a) === art_name
    assert String.to_integer(art_name2b) === art_name

    Neo4j.query!(Neo4j.conn, "MATCH (a:Article {title: '#{art_name}'})-[r]-() DELETE r, a")
  end

  @doc """
  GET /api/articles/:aricle_url
  """
  test "list an non-existent article" do
    conn = conn(:get, "/api/articles/non-existent")
    response = Router.call(conn, @opts)

    assert response.status === 404
  end
end
