defmodule SymbolsGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  GET /api/symbols
  """
  test "list all symbols" do
    conn = conn(:get, "/api/symbols", %{})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols" => _symbols} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/symbols?patches=all
  """
  test "Unauthenticated attempt at listing all patches for symbols" do
    conn = conn(:get, "/api/symbols", %{"patches" => "all"})
    response = Router.call(conn, @opts)

    assert response.status == 401
  end

  @doc """
  GET /api/symbols?patches=all -H 'authorization: at1'
  """
  test "Unauthorised attempt at listing all patches for symbols" do
    conn =
      conn(:get, "/api/symbols", %{"patches" => "all"})
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 403
  end

  @doc """
  GET /api/symbols?patches=all -H 'authorization: at2'
  """
  test "Authorised attempt 1 at listing all patches for symbols" do
    conn =
      conn(:get, "/api/symbols", %{"patches" => "all"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_patches" => _patches, "symbols_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?patches=all -H 'authorization: at3'
  """
  test "Authorised attempt 2 at listing all patches for symbols" do
    conn =
      conn(:get, "/api/symbols", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_patches" => _patches, "symbols_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?patches=insert -H 'authorization: at2'
  """
  test "Authorised attempt at listing all insert patches for symbols" do
    conn =
      conn(:get, "/api/symbols", %{"patches" => "insert"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?patches=update -H 'authorization: at2'
  """
  test "Authorised attempt at listing all update patches for symbols" do
    conn =
      conn(:get, "/api/symbols", %{"patches" => "update"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_updates" => _updates} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?patches=delete -H 'authorization: at2'
  """
  test "Authorised attempt at listing all delete patches for symbols" do
    conn =
      conn(:get, "/api/symbols", %{"patches" => "delete"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_deletes" => _deletes} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?search=existing_symbol
  """
  test "Search (regex) all symbols for an existing symbol" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {id: #{sym_id}, name: '#{sym_id}', description: '.', url: '#{sym_id}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/symbols", %{"search" => "#{String.slice(Integer.to_string(sym_id), 1..-2)}"})

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols" => [%{"symbol" => %{"id" => sym_id2}}]} = Poison.decode! response.resp_body
    assert sym_id2 == sym_id

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})-[r:CATEGORY]->(s:Symbol {revision_id: #{sym_rev}}) DELETE r, c, s
    """)
  end

  @doc """
  GET /api/symbols?search=non-existent
  """
  test "Search (regex) all symbols for a non-existent symbol" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {id: #{sym_id}, name: '...', description: '.', url: '...', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/symbols", %{"search" => "non-existent"})

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols" => []} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?search==existing_symbol
  """
  test "Search (exact name) all symbols for an existing symbol" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {id: #{sym_id}, name: '#{sym_id}', description: '.', url: '#{sym_id}', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/symbols", %{"search" => "=#{sym_id}"})

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols" => [%{"symbol" => %{"id" => sym_id2}}]} = Poison.decode! response.resp_body
    assert sym_id2 == sym_id

    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {revision_id: #{cat_rev}})-[r:CATEGORY]->(s:Symbol {revision_id: #{sym_rev}}) DELETE r, c, s
    """)
  end

  @doc """
  GET /api/symbols?search==non-existent
  """
  test "Search (exact name) all symbols for a non-existent symbol" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_id = :rand.uniform(100_000_000)
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}}),
        (s:Symbol {id: #{sym_id}, name: '...', description: '.', url: '...', definition: '.', definition_location: '..', type: 'macro', revision_id: #{sym_rev}}),
        (s)-[:CATEGORY]->(c)
    """)

    conn = conn(:get, "/api/symbols", %{"search" => "=#{String.slice(Integer.to_string(sym_id), 1..-2)}"})

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols" => []} = Poison.decode! response.resp_body
  end
end
