defmodule ArticlesGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/articles
  """
  test "list all articles overview" do
    conn = conn(:get, "/api/articles", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => _articles} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/articles?search=xiSten
  """
  test "search all articles by name" do
    conn = conn(:get, "/api/articles", %{"search" => "xiSten"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => articles} = Poison.decode!(response.resp_body)
    assert %{"article" => %{"title" => "existent"}} = List.first articles
  end

  @doc """
  GET /api/articles?search==exiStent
  """
  test "search all articles by exact name" do
    conn = conn(:get, "/api/articles", %{"search" => "=exiStent"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => articles} = Poison.decode!(response.resp_body)
    assert %{"article" => %{"title" => "existent"}} = List.first articles
  end

  @doc """
  GET /api/articles?search==xiSten
  """
  test "search all articles by exact name (no results)" do
    conn = conn(:get, "/api/articles", %{"search" => "=xiSten"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => []} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/articles?search=.&full_search=true
  """
  test "search all articles by body" do
    conn = conn(:get, "/api/articles", %{"search" => ".", "full_search" => 1})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => articles} = Poison.decode!(response.resp_body)
    assert %{"article" => %{}} = List.first articles
  end

  @doc """
  GET /api/articles?author=...
  """
  test "list all articles for a particular author" do
    art_name = :rand.uniform(100_000_000)
    user_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (u:User {id: #{user_id}, username: '#{user_id}', name: '#{user_id}', privilege_level: 3}),
        (a:Article {title: '#{art_name}', url: '#{art_name}', excerpt: '.', body: '.', date: timestamp()}),
        (a)-[:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(u),
        (a)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/articles", %{"author" => "#{user_id}"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => [%{"article" => %{"url" => art_name2}}]} = Poison.decode!(response.resp_body)
    assert String.to_integer(art_name2) === art_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: #{user_id}}),
        (a:Article {title: '#{art_name}'})-[r]-()
      DELETE r, a, u
    """)
  end

  @doc """
  GET /api/articles?author=...
  """
  test "list all articles for a particular author and existing category" do
    art_name = :rand.uniform(100_000_000)
    user_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (u:User {id: #{user_id}, username: '#{user_id}', name: '#{user_id}', privilege_level: 3}),
        (a:Article {title: '#{art_name}', url: '#{art_name}', excerpt: '.', body: '.', date: timestamp()}),
        (a)-[:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(u),
        (a)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/articles", %{"category" => "existent", "author" => "#{user_id}"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => [%{"article" => %{"url" => art_name2}}]} = Poison.decode!(response.resp_body)
    assert String.to_integer(art_name2) === art_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: #{user_id}}),
        (a:Article {title: '#{art_name}'})-[r]-()
      DELETE r, a, u
    """)
  end

  @doc """
  GET /api/articles?author=...
  """
  test "list all articles for a particular author and non-existent category" do
    art_name = :rand.uniform(100_000_000)
    user_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'})
      CREATE (u:User {id: #{user_id}, username: '#{user_id}', name: '#{user_id}', privilege_level: 3}),
        (a:Article {title: '#{art_name}', url: '#{art_name}', excerpt: '.', body: '.', date: timestamp()}),
        (a)-[:CONTRIBUTOR {type: "insert", date: 1, time: 2}]->(u),
        (a)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/articles", %{"category" => "non-existent", "author" => "#{user_id}"})
    response = Router.call(conn, @opts)

    assert response.status === 404
    assert %{"error" => %{"message" => "Category not found"}} = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: #{user_id}}),
        (a:Article {title: '#{art_name}'})-[r]-()
      DELETE r, a, u
    """)
  end

  @doc """
  GET /api/articles?author=...
  """
  test "list all articles for a particular author (no results)" do
    conn = conn(:get, "/api/articles", %{"author" => "user1"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"articles" => []} = Poison.decode!(response.resp_body)
  end
end
