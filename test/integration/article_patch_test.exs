defmodule ArticlePatchTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  PATCH /api/articles/:article_url -H 'authorization:at3'
  """
  test "authorised article update" do
    art_name = :rand.uniform(100_000_000)
    art_name2 = :rand.uniform(100_000_000)
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
        (a)-[:AUTHOR]->(u),
        (a)-[:CATEGORY]->(c),
        (:Category {
          name: '#{cat_name}',
          introduction: '..',
          url: '#{cat_name}',
          revision_id: #{cat_rev_id}
        })
    """)
    data = %{"article" => %{"title" => "#{art_name2}", "excerpt" => "...",
      "body" => ".", "categories" => ["#{cat_name}"], "series_name" => "#{ser_name}"}}

    conn =
      conn(:patch, "/api/articles/#{art_name}", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"article" =>
      %{"title" => art_name2a, "url" => art_name2b, "excerpt" => "...", "body" => ".",
        "date" => _date, "categories" => categories, "author" => %{"username" => "user3"},
        "series_name" => ser_name2}}
          = Poison.decode!(response.resp_body)
    assert [%{"category" => %{"name" => cat_name2a, "url" => cat_name2b}}] = categories
    assert String.to_integer(art_name2a) === art_name2
    assert String.to_integer(art_name2b) === art_name2
    assert String.to_integer(cat_name2a) === cat_name
    assert String.to_integer(cat_name2b) === cat_name
    assert String.to_integer(ser_name2) === ser_name

    Neo4j.query!(Neo4j.conn, "MATCH (a:Article {title: '#{art_name2}'})-[r]-() DELETE r, a")
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
