defmodule SymbolsGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/symbols
  """
  test "list all symbols" do
    conn = conn(:get, "/api/symbols", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => _symbols} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/symbols?patches=all
  """
  test "Unauthenticated attempt at listing all patches for symbols" do
    conn = conn(:get, "/api/symbols", %{"patches" => "all"})
    response = Router.call(conn, @opts)

    assert response.status === 401
  end

  @doc """
  GET /api/symbols?patches=all -H 'authorization: at1'
  """
  test "Unauthorised attempt at listing all patches for symbols" do
    conn =
      conn(:get, "/api/symbols", %{"patches" => "all"})
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 403
  end

  @doc """
  GET /api/symbols?patches=all -H 'authorization: at2'
  """
  test "Authorised attempt 1 at listing all patches for symbols" do
    conn =
      conn(:get, "/api/symbols", %{"patches" => "all"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
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

    assert response.status === 200
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

    assert response.status === 200
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

    assert response.status === 200
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

    assert response.status === 200
    assert %{"symbols_deletes" => _deletes} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?search=existing_symbol
  """
  test "Search (regex) all symbols for an existing symbol" do
    conn = conn(:get, "/api/symbols", %{"search" => "xisTen"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => [%{"symbol" => %{"url" => "existent"}}]} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?search=non-existent
  """
  test "Search (regex) all symbols for a non-existent symbol" do
    conn = conn(:get, "/api/symbols", %{"search" => "non-existent"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => symbols} = Poison.decode! response.resp_body
    assert [] === symbols
  end

  @doc """
  GET /api/symbols?search==existing_symbol
  """
  test "Search (exact name) all symbols for an existing symbol" do
    conn = conn(:get, "/api/symbols", %{"search" => "=Existent"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => [%{"symbol" => %{"url" => "existent"}}], "meta" => _}
      = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/symbols?search==non-existent
  """
  test "Search (exact name) all symbols for a non-existent symbol" do
    conn = conn(:get, "/api/symbols", %{"search" => "non-existent"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => symbols} = Poison.decode! response.resp_body
    assert [] === symbols
  end

  @doc """
  GET /api/symbols?search==existing_symbol
  """
  test "Search (exact name) all symbols for an existing symbol (cache test)" do
    sym_id = :rand.uniform(100_000_000)
    sym_name = Integer.to_string(:rand.uniform(100_000_000))
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {access_token: 'at2'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '#{sym_name}',
          description: '.',
          url: '#{sym_name}',
          definition: '.',
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR]->(u)
    """)

    # prime the cache
    conn = conn(:get, "/api/symbols", %{"search" => "=#{sym_name}"})
    response = Router.call(conn, @opts)
    assert response.status === 200
    assert %{"symbols" => [%{"symbol" => %{"url" => ^sym_name}}], "meta" => _}
      = Poison.decode! response.resp_body

    # acquire a lock
    conn =
      conn(:patch, "/api/locks/#{sym_rev}", %{"lock" => "acquire"})
      |> put_req_header("authorization", "at2")
    assert Router.call(conn, @opts).status === 200

    conn =
      conn(:delete, "/api/symbols/#{sym_id}", %{})
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)
    assert response.status === 204

    conn = conn(:get, "/api/symbols", %{"search" => "=#{sym_name}"})
    response = Router.call(conn, @opts)
    assert response.status === 200
    assert %{"symbols" => [], "meta" => _} = Poison.decode! response.resp_body

    # release the lock
    conn =
      conn(:patch, "/api/locks/#{sym_rev}", %{"lock" => "release"})
      |> put_req_header("authorization", "at2")
    assert Router.call(conn, @opts).status === 200

    Neo4j.query!(Neo4j.conn, "MATCH (s:SymbolDeleted {revision_id: #{sym_rev}})-[r]-() DELETE r, s")
  end

  @doc """
  GET /api/symbols?search==existing_symbol
  """
  test "Search (exact name) all symbols for an existing symbol (cache test 2)" do
    sym_id = :rand.uniform(100_000_000)
    sym_name = Integer.to_string(:rand.uniform(100_000_000))
    sym_rev = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, """
      MATCH (c:Category {url: 'existent'}),
        (u:User {access_token: 'at2'})
      CREATE (s:Symbol {
          id: #{sym_id},
          name: '#{sym_name}',
          description: '.',
          url: '#{sym_name}',
          definition: '.',
          source_location: '..',
          type: 'macro',
          revision_id: #{sym_rev}
        }),
        (s)-[:CATEGORY]->(c),
        (s)-[:CONTRIBUTOR]->(u)
    """)

    # prime the cache
    conn = conn(:get, "/api/symbols", %{"search" => "=#{sym_name}"})
    response = Router.call(conn, @opts)
    assert response.status === 200
    assert %{"symbols" => [%{"symbol" => %{"url" => ^sym_name}}], "meta" => _}
      = Poison.decode! response.resp_body

    # acquire a lock
    conn =
      conn(:patch, "/api/locks/#{sym_rev}", %{"lock" => "acquire"})
      |> put_req_header("authorization", "at1")
    assert Router.call(conn, @opts).status === 200

    conn =
      conn(:delete, "/api/symbols/#{sym_id}", %{})
      |> put_req_header("authorization", "at1")
    response = Router.call(conn, @opts)
    assert response.status === 202

    # release the lock
    conn =
      conn(:patch, "/api/locks/#{sym_rev}", %{"lock" => "release"})
      |> put_req_header("authorization", "at1")
    assert Router.call(conn, @opts).status === 200

    # acquire a lock
    conn =
      conn(:patch, "/api/locks/#{sym_rev}", %{"lock" => "acquire"})
      |> put_req_header("authorization", "at2")
    assert Router.call(conn, @opts).status === 200

    conn =
      conn(:patch, "/api/symbols/#{sym_id}?apply_patch=delete", %{})
      |> put_req_header("authorization", "at2")
    response = Router.call(conn, @opts)
    assert response.status === 204

    conn = conn(:get, "/api/symbols", %{"search" => "=#{sym_name}"})
    response = Router.call(conn, @opts)
    assert response.status === 200
    assert %{"symbols" => [], "meta" => _} = Poison.decode! response.resp_body

    # release the lock
    conn =
      conn(:patch, "/api/locks/#{sym_rev}", %{"lock" => "release"})
      |> put_req_header("authorization", "at2")
    assert Router.call(conn, @opts).status === 200

    Neo4j.query!(Neo4j.conn, "MATCH (s:SymbolDeleted {revision_id: #{sym_rev}})-[r]-() DELETE r, s")
  end

  @doc """
  GET /api/symbols?search=~&full_search=true
  """
  test "search all symbols by description" do
    conn = conn(:get, "/api/symbols", %{"search" => "~", "full_search" => "1"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => symbols} = Poison.decode!(response.resp_body)
    assert %{"symbol" => %{}} = List.first symbols
  end

  @doc """
  GET /api/symbols?category=existent
  """
  test "Filter all symbols by a specific category" do
    conn = conn(:get, "/api/symbols", %{"category" => "existent"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => symbols} = Poison.decode! response.resp_body
    assert %{"symbol" => %{}} = List.first symbols
  end

  @doc """
  GET /api/symbols?search=existing_symbol
  """
  test "Search (regex) all symbols by type for an existing symbol" do
    conn = conn(:get, "/api/symbols", %{"search" => "xisTen", "type" => "macro"})

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"symbols" => [%{"symbol" => %{"url" => "existent"}}]} = Poison.decode! response.resp_body
  end
end
