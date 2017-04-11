defmodule SymbolsPostTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  POST /api/symbols/
  """
  test "Unauthenticated attempt at inserting a new symbol" do
    conn =
      conn(:post, "/api/symbols")
      |> put_req_header("content-type", "application/json")

    response = Router.call(conn, @opts)

    assert response.status === 401
  end

  @doc """
  POST /api/symbols
  """
  test "Authorised invalid attempt at inserting a new symbol" do
    conn =
      conn(:post, "/api/symbols")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Malformed input data"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at1
  """
  test "Authenticated attempt at inserting a new symbol patch 1" do
    sym_name = :rand.uniform(100_000_000)
    data = %{"symbol" => %{"name" => "#{sym_name}", "description" => ".",
      "definition" => ".", "definition_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => ".."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatch {name: '#{sym_name}'}),
        (s)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at1'}),
        (s)-[:CATEGORY]->(:Category {url: 'existent'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, "MATCH (s:InsertSymbolPatch {name: '#{sym_name}'})-[r]-() DELETE r, s")
  end

  @doc """
  POST /api/symbols?review=1 -H authorization: at2
  """
  test "Authenticated attempt at inserting a new symbol patch 2" do
    sym_name = :rand.uniform(100_000_000)
    data = %{"review" => "1", "symbol" => %{"name" => "#{sym_name}", "description" => ".",
      "definition" => ".", "definition_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => ".."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatch {name: '#{sym_name}'}),
        (s)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at2'}),
        (s)-[:CATEGORY]->(:Category {url: 'existent'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, "MATCH (s:InsertSymbolPatch {name: '#{sym_name}'})-[r]-() DELETE r, s")
  end

  @doc """
  POST /api/symbols?review=1 -H authorization: at3
  """
  test "Authenticated attempt at inserting a new symbol patch 3" do
    sym_name = :rand.uniform(100_000_000)
    data = %{"review" => "1", "symbol" => %{"name" => "#{sym_name}", "description" => ".",
      "definition" => ".", "definition_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => ".."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 202
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:InsertSymbolPatch {name: '#{sym_name}'}),
        (s)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (s)-[:CATEGORY]->(:Category {url: 'existent'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, "MATCH (s:InsertSymbolPatch {name: '#{sym_name}'})-[r]-() DELETE r, s")
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Authenticated attempt at inserting a new symbol 1" do
    sym_name = :rand.uniform(100_000_000)
    data = %{"symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".",
      "definition_location" => ".", "type" => "macro", "categories" => ["existent"],
      "declaration" => ".."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {name: '#{sym_name}'}),
        (s)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at2'}),
        (s)-[:CATEGORY]->(:Category {url: 'existent'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {name: '#{sym_name}'})-[r]-() DELETE r, s")
  end

  @doc """
  POST /api/symbols -H authorization: at3
  """
  test "Authenticated attempt at inserting a new symbol 2" do
    sym_name = :rand.uniform(100_000_000)
    data = %{"symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".",
      "definition_location" => ".", "type" => "macro", "categories" => ["existent"],
      "declaration" => ".."}}

    conn =
      conn(:post, "/api/symbols/", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {name: '#{sym_name}'}),
        (s)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (s)-[:CATEGORY]->(:Category {url: 'existent'})
      RETURN s
    """)

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {name: '#{sym_name}'})-[r]-() DELETE r, s")
  end

  @doc """
  POST /api/symbols -H 'authorization: ...'
  """
  test "Authorised invalid attempt at inserting a new symbol (patch limit reached)" do
    name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (user:User {username: '#{name}', access_token: '#{name}', privilege_level: 1}),
        (c:UpdateCategoryPatch)
      FOREACH (ignored in RANGE(1, 20) |
        CREATE (c)-[:CONTRIBUTOR]->(user)
      )
    """)

    conn =
      conn(:post, "/api/symbols", %{"symbol" => %{}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "#{name}")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The maximum patch limit (20) has been exceeded!"}}
      = Poison.decode!(response.resp_body)

    Neo4j.query!(Neo4j.conn, "MATCH (u:User {username: '#{name}'})-[r]-(c) DELETE r, u, c")
  end
end
