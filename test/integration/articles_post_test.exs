defmodule ArticlesPostTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  POST /api/articles -H 'authorization:at3'
  """
  test "authorised article creation (with series name)" do
    art_name = :rand.uniform(100_000_000)
    data = %{"article" => %{"title" => "#{art_name}", "excerpt" => ".", "series_name" => "a",
      "body" => "...", "categories" => ["existent"]}}

    conn =
      conn(:post, "/api/articles", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 201
    assert %{"article" =>
      %{"title" => art_name2a, "url" => art_name2b, "excerpt" => ".", "body" => "...",
        "date" => _date, "series_name" => "a"}}
          = Poison.decode!(response.resp_body)
    assert String.to_integer(art_name2a) === art_name
    assert String.to_integer(art_name2b) === art_name

    Neo4j.query!(Neo4j.conn, "MATCH (a:Article {title: '#{art_name}'})-[r]-() DELETE r, a")
  end

  @doc """
  POST /api/articles -H 'authorization:at3'
  """
  test "authorised article creation (without series name)" do
    art_name = :rand.uniform(100_000_000)
    data = %{"article" => %{"title" => "#{art_name}", "excerpt" => ".", "series_name" => "",
      "body" => "...", "categories" => ["existent"]}}

    conn =
      conn(:post, "/api/articles", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 201
    assert %{"article" =>
      %{"title" => art_name2a, "url" => art_name2b, "excerpt" => ".", "body" => "...",
        "date" => _date, "series_name" => ""}}
          = Poison.decode!(response.resp_body)
    assert String.to_integer(art_name2a) === art_name
    assert String.to_integer(art_name2b) === art_name

    Neo4j.query!(Neo4j.conn, "MATCH (a:Article {title: '#{art_name}'})-[r]-() DELETE r, a")
  end

  @doc """
  POST /api/articles -H 'authorization:at2'
  """
  test "unauthorised article creation (at2)" do
    art_name = :rand.uniform(100_000_000)
    data = %{"article" => %{"title" => "#{art_name}", "excerpt" => ".", "series_name" => "",
      "body" => "...", "categories" => ["existent"]}}

    conn =
      conn(:post, "/api/articles", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)

    assert response.status === 403
    assert %{"error" => %{"message" => "Unauthorised access attempt"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/articles -H 'authorization:at1'
  """
  test "unauthorised article creation (at1)" do
    art_name = :rand.uniform(100_000_000)
    data = %{"article" => %{"title" => "#{art_name}", "excerpt" => ".", "series_name" => "",
      "body" => "...", "categories" => ["existent"]}}

    conn =
      conn(:post, "/api/articles", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)

    assert response.status === 403
    assert %{"error" => %{"message" => "Unauthorised access attempt"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/articles
  """
  test "unauthenticated article creation" do
    art_name = :rand.uniform(100_000_000)
    data = %{"article" => %{"title" => "#{art_name}", "excerpt" => ".", "series_name" => "",
      "body" => "...", "categories" => ["existent"]}}

    conn =
      conn(:post, "/api/articles", data)
      |> put_req_header("content-type", "application/json")
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/articles -H 'authorization:at3'
  """
  test "authorised invalid article creation (missing excerpt field)" do
    art_name = :rand.uniform(100_000_000)
    data = %{"article" => %{"title" => "#{art_name}", "series_name" => "",
      "body" => "...", "categories" => ["existent"]}}

    conn =
      conn(:post, "/api/articles", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Required fields are missing (expecting: title, body, categories, excerpt, series_name)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/articles -H 'authorization:at3'
  """
  test "authorised invalid article creation (unknown field given)" do
    art_name = :rand.uniform(100_000_000)
    data = %{"article" => %{"title" => "#{art_name}", "excerpt" => ".", "series_name" => "",
      "body" => "...", "categories" => ["existent"], "a" => "b"}}

    conn =
      conn(:post, "/api/articles", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Unknown fields given (expecting: title, body, categories, excerpt, series_name)"}}
      = Poison.decode!(response.resp_body)
  end
end
