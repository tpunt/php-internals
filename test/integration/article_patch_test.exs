defmodule ArticlePatchTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  PATCH /api/articles/:article_url -H 'authorization:at3'
  """
  test "authorised article update" do
    art_name = :rand.uniform(100_000_000)
    ser_name = :rand.uniform(100_000_000)
    cat_name = :rand.uniform(100_000_000)
    cat_rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3}), (c:Category {url: 'existent'})
      CREATE (a:Article {
          title: '#{art_name}',
          url: '#{art_name}',
          series_name: '',
          series_url: '',
          excerpt: '.',
          body: '...',
          date: timestamp()
        }),
        (a)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 2}]->(u),
        (a)-[:CATEGORY]->(c),
        (:Category {
          name: '#{cat_name}',
          introduction: '..',
          url: '#{cat_name}',
          revision_id: #{cat_rev_id}
        })
    """)
    data = %{"article" => %{"title" => "#{art_name}2", "excerpt" => "...",
      "body" => ".", "categories" => ["#{cat_name}"], "series_name" => "#{ser_name}"}}

    # prime the cache
    conn = conn(:get, "/api/articles/#{art_name}", %{})
    Router.call(conn, @opts)

    conn =
      conn(:patch, "/api/articles/#{art_name}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"article" =>
      %{"title" => art_name2a, "url" => art_name2b, "excerpt" => "...", "body" => ".",
        "time" => _time, "categories" => categories, "author" => %{"username" => "user3"},
        "series_name" => ser_name2}}
          = Poison.decode!(response.resp_body)
    assert [%{"category" => %{"name" => cat_name2a, "url" => cat_name2b}}] = categories
    assert art_name2a === "#{art_name}2"
    assert art_name2b === "#{art_name}2"
    assert String.to_integer(cat_name2a) === cat_name
    assert String.to_integer(cat_name2b) === cat_name
    assert String.to_integer(ser_name2) === ser_name

    conn = conn(:get, "/api/articles/#{art_name}")
    response2 = Router.call(conn, @opts)

    assert response2.status === 404

    conn = conn(:get, "/api/articles/#{art_name}2")
    response2 = Router.call(conn, @opts)

    assert response2.status === 200
    assert Poison.decode!(response2.resp_body) === Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (a:Article {title: '#{art_name}2'})-[r]-() DELETE r, a")
  end

  @doc """
  PATCH /api/articles/:article_url -H 'authorization:at3'
  """
  test "authorised article update without series name" do
    art_name = :rand.uniform(100_000_000)
    cat_name = :rand.uniform(100_000_000)
    cat_rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3}), (c:Category {url: 'existent'})
      CREATE (a:Article {
          title: '#{art_name}',
          url: '#{art_name}',
          series_name: '',
          series_url: '',
          excerpt: '.',
          body: '...',
          date: timestamp()
        }),
        (a)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 2}]->(u),
        (a)-[:CATEGORY]->(c),
        (:Category {
          name: '#{cat_name}',
          introduction: '..',
          url: '#{cat_name}',
          revision_id: #{cat_rev_id}
        })
    """)
    data = %{"article" => %{"title" => "#{art_name}", "excerpt" => "...",
      "body" => ".", "categories" => ["#{cat_name}"]}}

    # prime the cache
    conn = conn(:get, "/api/articles/#{art_name}", %{})
    Router.call(conn, @opts)

    conn =
      conn(:patch, "/api/articles/#{art_name}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"article" =>
      %{"title" => art_name2a, "url" => art_name2b, "excerpt" => "...", "body" => ".",
        "time" => _time, "categories" => categories, "author" => %{"username" => "user3"},
        "series_name" => ""}}
          = Poison.decode!(response.resp_body)
    assert [%{"category" => %{"name" => cat_name2a, "url" => cat_name2b}}] = categories
    assert String.to_integer(art_name2a) === art_name
    assert String.to_integer(art_name2b) === art_name
    assert String.to_integer(cat_name2a) === cat_name
    assert String.to_integer(cat_name2b) === cat_name

    conn = conn(:get, "/api/articles/#{art_name}")
    response2 = Router.call(conn, @opts)

    assert response2.status === 200
    assert Poison.decode!(response2.resp_body) === Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (a:Article {title: '#{art_name}'})-[r]-() DELETE r, a")
  end

  @doc """
  PATCH /api/articles/:article_url -H 'authorization:at3'
  """
  test "authorised invalid article update (article with the same name already exists)" do
    art_name = :rand.uniform(100_000_000)
    ser_name = :rand.uniform(100_000_000)
    cat_name = :rand.uniform(100_000_000)
    cat_rev_id = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {id: 3}), (c:Category {url: 'existent'})
      CREATE (a:Article {
          title: '#{art_name}',
          url: '#{art_name}',
          series_name: '',
          series_url: '',
          excerpt: '.',
          body: '...',
          date: timestamp()
        }),
        (a)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 2}]->(u),
        (a)-[:CATEGORY]->(c),
        (:Category {
          name: '#{cat_name}',
          introduction: '..',
          url: '#{cat_name}',
          revision_id: #{cat_rev_id}
        })
    """)
    data = %{"article" => %{"title" => "existent", "excerpt" => "...",
      "body" => ".", "categories" => ["#{cat_name}"], "series_name" => "#{ser_name}"}}

    conn =
      conn(:patch, "/api/articles/#{art_name}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The article with the specified name already exists"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (a:Article {title: '#{art_name}'})-[r]-() DELETE r, a")
  end

  @doc """
  PATCH /api/articles/:article_url -H 'authorization:at2'
  """
  test "unauthorised article update (at2)" do
    conn =
      conn(:patch, "/api/articles/...", %{})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status === 403
    assert %{"error" => %{"message" => "Unauthorised access attempt"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/articles/:article_url -H 'authorization:at1'
  """
  test "unauthorised article update (at1)" do
    conn =
      conn(:patch, "/api/articles/...", %{})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status === 403
    assert %{"error" => %{"message" => "Unauthorised access attempt"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  PATCH /api/articles/:article_url
  """
  test "unauthorised article update" do
    conn =
      conn(:patch, "/api/articles/...", %{})
      |> put_req_header("content-type", "application/json")
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}}
      = Poison.decode!(response.resp_body)
  end
end
