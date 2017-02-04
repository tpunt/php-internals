defmodule SymbolGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  GET /api/symbols/non-existent?view=overview
  """
  test "get a non-existent symbol's overview" do
    conn = conn(:get, "/api/symbols/non-existent", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status == 404
  end

  @doc """
  GET /api/symbols/non-existent
  """
  test "get a non-existent symbol" do
    conn = conn(:get, "/api/symbols/non-existent")
    response = Router.call(conn, @opts)

    assert response.status == 404
  end

  @doc """
  GET /api/symbols/non-existent?view=unknown
  """
  test "get a non-existent symbol with an unknown view" do
    conn = conn(:get, "/api/symbols/non-existent", %{"view" => "unknown"})
    response = Router.call(conn, @opts)

    assert response.status == 400
    assert %{"error" => %{"message" => "Unknown view type"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?view=overview
  """
  test "get an existing symbol's overview" do
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}})")

    conn = conn(:get, "/api/symbols/#{sym_name}", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol" => %{"name" => sym_name2, "url" => sym_url, "type" => "macro"}} = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}}) DELETE s")
  end

  @doc """
  GET /api/symbols/existent
  """
  test "get an existing symbol" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/symbols/#{sym_name}")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol" => %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}} = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}})-[r:CATEGORY]->(c:Category {revision_id: #{cat_rev}}) DELETE r, s, c")
  end

  @doc """
  GET /api/symbols/non-existent?patches=delete -H authorization:at3
  """
  test "get an non-existent symbol's delete patch" do
    conn =
      conn(:get, "/api/symbols/non-existent", %{"patches" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "The specified symbol could not be found"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?patches=delete -H authorization:at3
  """
  test "get an existing symbol's invalid delete patch" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "The specified symbol delete patch could not be found"}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}})-[r:CATEGORY]->(c:Category {revision_id: #{cat_rev}}) DELETE r, s, c")
  end

  @doc """
  GET /api/symbols/existent?patches=delete -H authorization:at3
  """
  test "get an existing symbol's delete patch" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c),
        (s)-[:DELETE]->(:DeleteSymbolPatch)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "delete"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_delete" =>
      %{"symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {revision_id: #{cat_rev}}),
        (s)-[r1:DELETE]->(sd:DeleteSymbolPatch),
        (s)-[r2:CATEGORY]->(c)
      DELETE r1, r2, sd, s, c
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=insert -H authorization:at3
  """
  test "get an non-existent symbol's insert patch" do
    conn =
      conn(:get, "/api/symbols/non-existent", %{"patches" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "The specified symbol insert patch could not be found"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols/existent?patches=insert -H authorization:at3
  """
  test "get an existing symbol's insert patch" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:InsertSymbolPatch {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "insert"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_insert" =>
      %{"symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, "MATCH (s:InsertSymbolPatch {revision_id: #{sym_rev}})-[r:CATEGORY]->(c:Category {revision_id: #{cat_rev}}) DELETE r, s, c")
  end

  @doc """
  GET /api/symbols/existent?patches=update -H authorization:at3
  """
  test "get an existing symbol's update patches 1" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "update"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_updates" =>
      %{"updates" => [], "symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {revision_id: #{sym_rev}})-[r:CATEGORY]->(c:Category {revision_id: #{cat_rev}}) DELETE r, s, c")
  end

  @doc """
  GET /api/symbols/existent?patches=update -H authorization:at3
  """
  test "get an existing symbol's update patches 2" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    sym_name_b = :rand.uniform(100_000_000)
    sym_rev_b = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s2:UpdateSymbolPatch {name: '#{sym_name_b}', description: '.2', url: '#{sym_name_b}', definition: '.2', definition_location: '..2', type: 'macro', revision_id: #{sym_rev_b}}),
        (s2)-[:CATEGORY]->(c),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "update"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_updates" =>
      %{"updates" => updates, "symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name
    assert [%{"update" =>
      %{"name" => sym_name2, "description" => ".2", "url" => sym_url, "definition" => ".2", "definition_location" => "..2", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}] = updates
    assert String.to_integer(sym_name2) == sym_name_b
    assert String.to_integer(sym_url) == sym_name_b
    assert sym_rev2 == sym_rev_b
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}}),
        (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}}),
        (s:Symbol {revision_id: #{sym_rev}}),
        (su)-[r1:CATEGORY]-(c),
        (s)-[r2:CATEGORY]-(c),
        (s)-[r3:UPDATE]-(su)
      DELETE r1, r2, r3, su, s, c
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=update&patch_id=invalid -H authorization:at3
  """
  test "get an existing symbol's invalid update patch" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "update", "patch_id" => "1"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 404
    assert %{"error" => %{"message" => "The specified symbol update patch could not be found"}} = Poison.decode! response.resp_body

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}}),
        (s:Symbol {revision_id: #{sym_rev}}),
        (s)-[r:CATEGORY]-(c)
      DELETE r, s, c
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=update&patch_id=... -H authorization:at3
  """
  test "get an existing symbol's update patch" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    sym_name_b = :rand.uniform(100_000_000)
    sym_rev_b = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s2:UpdateSymbolPatch {name: '#{sym_name_b}', description: '.2', url: '#{sym_name_b}', definition: '.2', definition_location: '..2', type: 'macro', revision_id: #{sym_rev_b}}),
        (s2)-[:CATEGORY]->(c),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "update", "patch_id" => "#{sym_rev_b}"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_update" =>
      %{"update" => update, "symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name
    assert %{"name" => sym_name2, "description" => ".2", "url" => sym_url, "definition" => ".2", "definition_location" => "..2", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories} = update
    assert String.to_integer(sym_name2) == sym_name_b
    assert String.to_integer(sym_url) == sym_name_b
    assert sym_rev2 == sym_rev_b
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}}),
        (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}}),
        (s:Symbol {revision_id: #{sym_rev}}),
        (su)-[r1:CATEGORY]-(c),
        (s)-[r2:CATEGORY]-(c),
        (s)-[r3:UPDATE]-(su)
      DELETE r1, r2, r3, su, s, c
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=all -H authorization:at3
  """
  test "get an existing symbol's patches 1" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_patches" =>
      %{"patches" => %{"updates" => [], "delete" => 0}, "symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}}),
        (s:Symbol {revision_id: #{sym_rev}}),
        (s)-[r:CATEGORY]-(c)
      DELETE r, s, c
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=all -H authorization:at3
  """
  test "get an existing symbol's patches 2" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    sym_name_b = :rand.uniform(100_000_000)
    sym_rev_b = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s2:UpdateSymbolPatch {name: '#{sym_name_b}', description: '.2', url: '#{sym_name_b}', definition: '.2', definition_location: '..2', type: 'macro', revision_id: #{sym_rev_b}}),
        (s2)-[:CATEGORY]->(c),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_patches" =>
      %{"patches" => %{"updates" => updates, "delete" => 0}, "symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name
    assert [%{"update" =>
      %{"name" => sym_name2, "description" => ".2", "url" => sym_url, "definition" => ".2", "definition_location" => "..2", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}] = updates
    assert String.to_integer(sym_name2) == sym_name_b
    assert String.to_integer(sym_url) == sym_name_b
    assert sym_rev2 == sym_rev_b
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}}),
        (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}}),
        (s:Symbol {revision_id: #{sym_rev}}),
        (su)-[r1:CATEGORY]-(c),
        (s)-[r2:CATEGORY]-(c),
        (s)-[r3:UPDATE]-(su)
      DELETE r1, r2, r3, su, s, c
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=all -H authorization:at3
  """
  test "get an existing symbol's patches 3" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c),
        (s)-[:DELETE]->(:DeleteSymbolPatch)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_patches" =>
      %{"patches" => %{"updates" => [], "delete" => 1}, "symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (s:Symbol {revision_id: #{sym_rev}}),
        (c:Category {revision_id: #{cat_rev}}),
        (s)-[r1:DELETE]->(sd:DeleteSymbolPatch),
        (s)-[r2:CATEGORY]->(c)
      DELETE r1, r2, sd, s, c
    """)
  end

  @doc """
  GET /api/symbols/existent?patches=all -H authorization:at3
  """
  test "get an existing symbol's patches 4" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    sym_name_b = :rand.uniform(100_000_000)
    sym_rev_b = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {name: '#{sym_name}', description: '.', url: '#{sym_name}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s2:UpdateSymbolPatch {name: '#{sym_name_b}', description: '.2', url: '#{sym_name_b}', definition: '.2', definition_location: '..2', type: 'macro', revision_id: #{sym_rev_b}}),
        (s2)-[:CATEGORY]->(c),
        (s)-[:CATEGORY]->(c),
        (s)-[:UPDATE]->(s2),
        (s)-[:DELETE]->(:DeleteSymbolPatch)
    """)

    conn =
      conn(:get, "/api/symbols/#{sym_name}", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbol_patches" =>
      %{"patches" => %{"updates" => updates, "delete" => 1}, "symbol" =>
        %{"name" => sym_name2, "description" => ".", "url" => sym_url, "definition" => ".", "definition_location" => "..", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}}
          = Poison.decode! response.resp_body
    assert String.to_integer(sym_name2) == sym_name
    assert String.to_integer(sym_url) == sym_name
    assert sym_rev2 == sym_rev
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name
    assert [%{"update" =>
      %{"name" => sym_name2, "description" => ".2", "url" => sym_url, "definition" => ".2", "definition_location" => "..2", "type" => "macro", "revision_id" => sym_rev2, "categories" => categories}}] = updates
    assert String.to_integer(sym_name2) == sym_name_b
    assert String.to_integer(sym_url) == sym_name_b
    assert sym_rev2 == sym_rev_b
    assert [%{"category" => %{"name" => cat_name2, "url" => cat_url}}] = categories
    assert String.to_integer(cat_name2) == cat_name
    assert String.to_integer(cat_url) == cat_name

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}}),
        (su:UpdateSymbolPatch {revision_id: #{sym_rev_b}}),
        (s:Symbol {revision_id: #{sym_rev}}),
        (su)-[r1:CATEGORY]-(c),
        (s)-[r2:CATEGORY]-(c),
        (s)-[r3:UPDATE]-(su),
        (s)-[r4:DELETE]->(sd:DeleteSymbolPatch)
      DELETE r1, r2, r3, r4, sd, su, s, c
    """)
  end
end
