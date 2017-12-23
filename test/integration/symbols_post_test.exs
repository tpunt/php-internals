defmodule SymbolsPostTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

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
      "definition" => ".", "source_location" => ".", "type" => "macro",
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
      "definition" => ".", "source_location" => ".", "type" => "macro",
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
      "definition" => ".", "source_location" => ".", "type" => "macro",
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
      "source_location" => ".", "type" => "macro", "categories" => ["existent"],
      "declaration" => "..", "additional_information" => "."}}

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

    body = Poison.decode!(response.resp_body)

    conn = conn(:get, "/api/symbols/#{body["symbol"]["symbol_id"]}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200

    conn = conn(:get, "/api/symbols", %{"search" => "=#{sym_name}"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => [%{"symbol" => %{"type" => "macro"}}], "meta" => _}
      = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {name: '#{sym_name}'})-[r]-() DELETE r, s")
  end

  @doc """
  POST /api/symbols -H authorization: at3
  """
  test "Authenticated attempt at inserting a new symbol 2" do
    sym_name = :rand.uniform(100_000_000)
    data = %{"symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".",
      "source_location" => ".", "type" => "macro", "categories" => ["existent"],
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

    body = Poison.decode!(response.resp_body)

    conn = conn(:get, "/api/symbols/#{body["symbol"]["symbol_id"]}", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200

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
        CREATE (c)-[:CONTRIBUTOR {date: 20170830, time: 2}]->(user)
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

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (name field length < 1)" do
    data = %{"symbol" => %{"name" => "", "description" => ".", "definition" => ".",
      "source_location" => ".", "type" => "macro", "categories" => ["existent"],
      "declaration" => ".."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The name field should have a length of between 1 and 100 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (name field length > 100)" do
    data = %{"symbol" => %{"name" => String.duplicate("a", 101), "description" => ".",
      "definition" => ".", "source_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => ".."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The name field should have a length of between 1 and 100 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (declaration field length < 1)" do
    data = %{"symbol" => %{"name" => "a", "description" => ".",
      "definition" => ".", "source_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => ""}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The declaration field should have a length of between 1 and 200 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (declaration field length > 200)" do
    data = %{"symbol" => %{"name" => "a", "description" => ".",
      "definition" => ".", "source_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => String.duplicate("a", 201)}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The declaration field should have a length of between 1 and 200 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (description field length < 1)" do
    data = %{"symbol" => %{"name" => "a", "description" => "",
      "definition" => ".", "source_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => "a"}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The description field should have a length of between 1 and 3000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (description field length > 3000)" do
    data = %{"symbol" => %{"name" => "a", "description" => String.duplicate("a", 3001),
      "definition" => ".", "source_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => "."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The description field should have a length of between 1 and 3000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (definition field length < 1)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "", "source_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => "a"}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The definition field should have a length of between 1 and 6000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (definition field length > 6000)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => String.duplicate("a", 6001), "source_location" => ".",
      "type" => "macro", "categories" => ["existent"], "declaration" => "."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The definition field should have a length of between 1 and 6000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (definition location field length < 1)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "", "type" => "macro",
      "categories" => ["existent"], "declaration" => "a"}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The definition location field should have a length of between 1 and 500 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (definition location field length > 500)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => String.duplicate("a", 501),
      "type" => "macro", "categories" => ["existent"], "declaration" => "."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The definition location field should have a length of between 1 and 500 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (type field invalid)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "invalid", "categories" => ["existent"], "declaration" => "."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The type field must be one of the following values: macro, function, variable, type"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (category field length < 1)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "macro", "categories" => [""], "declaration" => "."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Invalid category name(s) given"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (category field length > 50)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "macro", "categories" => [String.duplicate("a", 51)], "declaration" => "."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Invalid category name(s) given"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (odd parameter count)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "macro", "categories" => ["a"], "declaration" => ".",
      "parameters" => ["a"]}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "An even number of values is required"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (odd member count)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "type", "categories" => ["a"], "declaration" => ".",
      "members" => ["a"]}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "An even number of values is required"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (parameter field name length < 1)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "macro", "categories" => ["a"], "declaration" => ".",
      "parameters" => ["", "a"]}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The parameters field name must have a length of between 1 and 50 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (parameter field name length > 50)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "macro", "categories" => ["a"], "declaration" => ".",
      "parameters" => [String.duplicate("a", 51), "a"]}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The parameters field name must have a length of between 1 and 50 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (parameter field description length < 1)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "macro", "categories" => ["a"], "declaration" => ".",
      "parameters" => ["a", ""]}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The parameters field description must have a length of between 1 and 2000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (parameter field description length > 150)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "macro", "categories" => ["a"], "declaration" => ".",
      "parameters" => ["a", String.duplicate("a", 2001)]}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The parameters field description must have a length of between 1 and 2000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (return_type field length < 1)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "function", "categories" => ["a"], "declaration" => ".",
      "return_type" => ""}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The return type field should have a length of between 1 and 50 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (return_type field length > 50)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "function", "categories" => ["a"], "declaration" => ".",
      "return_type" => String.duplicate("a", 51)}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The return type field should have a length of between 1 and 50 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (return_description field length > 150)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "function", "categories" => ["a"], "declaration" => ".",
      "return_type" => "a", "return_description" => String.duplicate("a", 401)}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The return description field should have a length of 400 or less"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (additional_information field length > 2000)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "function", "categories" => ["a"], "declaration" => ".",
      "return_type" => "a", "return_description" => "a",
      "additional_information" => String.duplicate("a", 4_001)}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The additional information field should have a length of 4000 or less"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (duplicate category names)" do
    data = %{"symbol" => %{"name" => ".", "description" => ".", "definition" => ".",
      "source_location" => ".", "type" => "macro", "categories" => ["existent", "existent"],
      "declaration" => ".."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Duplicate category names given"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at3
  """
  test "Authenticated attempt at inserting a new symbol (cache invalidation test)" do
    cat_name = Integer.to_string(:rand.uniform(100_000_000))
    cat_revid = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at3'})

      CREATE (c:Category {name: '#{cat_name}', introduction: '.', url: '#{cat_name}', revision_id: #{cat_revid}}),
        (c)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 6}]->(u)
    """)

    data = %{"symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".",
      "source_location" => ".", "type" => "macro", "categories" => [cat_name],
      "declaration" => ".."}}

    # prime the cache
    response = Router.call(conn(:get, "/api/symbols", %{"category" => cat_name}), @opts)

    assert %{"symbols" => []} = Poison.decode!(response.resp_body)

    conn =
      conn(:post, "/api/symbols/", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 201
    refute [] === Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {name: '#{sym_name}'}),
        (s)-[:CONTRIBUTOR {type: 'insert'}]->(:User {access_token: 'at3'}),
        (s)-[:CATEGORY]->(:Category {url: '#{cat_name}'})
      RETURN s
    """)

    response = Router.call(conn(:get, "/api/symbols", %{"category" => "#{cat_name}"}), @opts)

    refute [] === Poison.decode!(response.resp_body)["symbols"]

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{cat_name}'}),
        (s:Symbol {name: '#{sym_name}'})
      DETACH DELETE c, s
    """)
  end

  @doc """
  POST /api/symbols -H authorization: at3
  """
  test "Authenticated attempt at inserting a new duplicated symbol (cache invalidation test)" do
    cat_name = Integer.to_string(:rand.uniform(100_000_000))
    cat_revid = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)

    Neo4j.query!(Neo4j.conn, """
      MATCH (u:User {access_token: 'at3'})

      CREATE (c:Category {name: '#{cat_name}', introduction: '.', url: '#{cat_name}', revision_id: #{cat_revid}}),
        (c)-[:CONTRIBUTOR {type: "insert", date: 20170810, time: 6}]->(u)
    """)

    data = %{"symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".",
      "source_location" => ".", "type" => "macro", "categories" => [cat_name],
      "declaration" => ".."}}

    # prime the cache
    response = Router.call(conn(:get, "/api/symbols", %{"category" => cat_name}), @opts)

    assert %{"symbols" => []} = Poison.decode!(response.resp_body)

    conn =
      conn(:post, "/api/symbols/", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)
    assert response.status === 201

    # prime the cache
    response = Router.call(conn(:get, "/api/symbols", %{"search" => "=#{sym_name}"}), @opts)
    assert 1 === Poison.decode!(response.resp_body)["meta"]["total"]

    response = Router.call(conn, @opts)
    assert response.status === 201

    response = Router.call(conn(:get, "/api/symbols", %{"search" => "=#{sym_name}"}), @opts)
    assert 2 === Poison.decode!(response.resp_body)["meta"]["total"]

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {name: '#{cat_name}'}),
        (s:Symbol {name: '#{sym_name}'})
      DETACH DELETE c, s
    """)
  end
end
