defmodule ArticleGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/articles/:aricle_url
  """
  test "list an existing article" do
    conn = conn(:get, "/api/articles/existent")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"article" => %{"title" => "existent", "url" => "existent", "excerpt" => ".",
      "body" => ".", "date" => _date}} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/articles/:aricle_url
  """
  test "list an non-existent article" do
    conn = conn(:get, "/api/articles/non-existent")
    response = Router.call(conn, @opts)

    assert response.status === 404
  end

  @doc """
  GET /api/articles/:aricle_url
  """
  test "list an existing article series" do
    art_name = :rand.uniform(100_000_000)
    ser_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3}), (c:Category {url: 'existent'})
      CREATE (a:Article {
          title: '#{art_name}',
          url: '#{art_name}',
          excerpt: '.',
          body: '...',
          date: timestamp(),
          series_name: '#{ser_name}',
          series_url: '#{ser_name}'
        }),
        (a)-[:AUTHOR]->(u),
        (a)-[:CATEGORY]->(c)
    """)
    conn = conn(:get, "/api/articles/#{ser_name}")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => [%{"article" => %{"title" => art_name2a, "url" => art_name2b,
      "excerpt" => ".", "date" => _date, "series_name" => ser_name2a, "series_url" => ser_name2b}}]}
        = Poison.decode!(response.resp_body)
    assert String.to_integer(art_name2a) === art_name
    assert String.to_integer(art_name2b) === art_name
    assert String.to_integer(ser_name2a) === ser_name
    assert String.to_integer(ser_name2b) === ser_name

    Neo4j.query!(Neo4j.conn, "MATCH (a:Article {title: '#{art_name}'})-[r]-() DELETE r, a")
  end
end
