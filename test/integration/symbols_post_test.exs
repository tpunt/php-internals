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
    assert %{"error" => %{"message" => "The declaration field should have a length of between 1 and 150 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (declaration field length > 150)" do
    data = %{"symbol" => %{"name" => "a", "description" => ".",
      "definition" => ".", "source_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => String.duplicate("a", 151)}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The declaration field should have a length of between 1 and 150 (inclusive)"}}
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
    assert %{"error" => %{"message" => "The description field should have a length of between 1 and 1000 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (description field length > 1000)" do
    data = %{"symbol" => %{"name" => "a", "description" => String.duplicate("a", 1001),
      "definition" => ".", "source_location" => ".", "type" => "macro",
      "categories" => ["existent"], "declaration" => "."}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The description field should have a length of between 1 and 1000 (inclusive)"}}
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
    assert %{"error" => %{"message" => "The parameters field description must have a length of between 1 and 400 (inclusive)"}}
      = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Invalid symbol insert (parameter field description length > 150)" do
    data = %{"symbol" => %{"name" => "a", "description" => "a",
      "definition" => "a", "source_location" => "a",
      "type" => "macro", "categories" => ["a"], "declaration" => ".",
      "parameters" => ["a", String.duplicate("a", 401)]}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The parameters field description must have a length of between 1 and 400 (inclusive)"}}
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
      "additional_information" => String.duplicate("a", 2_001)}}

    conn =
      conn(:post, "/api/symbols", data)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "The additional information field should have a length of 2000 or less"}}
      = Poison.decode!(response.resp_body)
  end
end
