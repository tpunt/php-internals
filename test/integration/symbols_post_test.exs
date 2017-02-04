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
      conn(:post, "/api/symbols/")
      |> put_req_header("content-type", "application/json")

    response = Router.call(conn, @opts)

    assert response.status == 401
  end

  @doc """
  POST /api/symbols
  """
  test "Authorised invalid attempt at inserting a new symbol" do
    conn =
      conn(:post, "/api/symbols/")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 400
    assert %{"error" => %{"message" => "Bad request data format"}} = Poison.decode!(response.resp_body)
  end

  @doc """
  POST /api/symbols -H authorization: at1
  """
  test "Authenticated attempt at inserting a new symbol patch 1" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}})")

    conn =
      conn(:post, "/api/symbols/", %{"symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".", "definition_location" => ".", "type" => "macro", "categories" => ["#{cat_name}"]}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 202
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertSymbolPatch {name: '#{sym_name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (s:InsertSymbolPatch {name: '#{sym_name}'})-[r:CATEGORY]->(c:Category {name: '#{cat_name}'}) DELETE r, s, c")
  end

  @doc """
  POST /api/symbols?review=1 -H authorization: at2
  """
  test "Authenticated attempt at inserting a new symbol patch 2" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}})")

    conn =
      conn(:post, "/api/symbols/", %{"review" => "1", "symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".", "definition_location" => ".", "type" => "macro", "categories" => ["#{cat_name}"]}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 202
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertSymbolPatch {name: '#{sym_name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (s:InsertSymbolPatch {name: '#{sym_name}'})-[r:CATEGORY]->(c:Category {name: '#{cat_name}'}) DELETE r, s, c")
  end

  @doc """
  POST /api/symbols?review=1 -H authorization: at3
  """
  test "Authenticated attempt at inserting a new symbol patch 3" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}})")

    conn =
      conn(:post, "/api/symbols/", %{"review" => "1", "symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".", "definition_location" => ".", "type" => "macro", "categories" => ["#{cat_name}"]}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 202
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertSymbolPatch {name: '#{sym_name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (s:InsertSymbolPatch {name: '#{sym_name}'})-[r:CATEGORY]->(c:Category {name: '#{cat_name}'}) DELETE r, s, c")
  end

  @doc """
  POST /api/symbols -H authorization: at2
  """
  test "Authenticated attempt at inserting a new symbol 1" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}})")

    conn =
      conn(:post, "/api/symbols/", %{"symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".", "definition_location" => ".", "type" => "macro", "categories" => ["#{cat_name}"]}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 201
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Symbol {name: '#{sym_name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {name: '#{sym_name}'})-[r:CATEGORY]->(c:Category {name: '#{cat_name}'}) DELETE r, s, c")
  end

  @doc """
  POST /api/symbols -H authorization: at3
  """
  test "Authenticated attempt at inserting a new symbol 2" do
    cat_name = :rand.uniform(100_000_000)
    cat_rev = :rand.uniform(100_000_000)
    sym_name = :rand.uniform(100_000_000)
    Neo4j.query!(Neo4j.conn, "CREATE (c:Category {name: '#{cat_name}', introduction: '...', url: '#{cat_name}', revision_id: #{cat_rev}})")

    conn =
      conn(:post, "/api/symbols/", %{"symbol" => %{"name" => "#{sym_name}", "description" => ".", "definition" => ".", "definition_location" => ".", "type" => "macro", "categories" => ["#{cat_name}"]}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 201
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Symbol {name: '#{sym_name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (s:Symbol {name: '#{sym_name}'})-[r:CATEGORY]->(c:Category {name: '#{cat_name}'}) DELETE r, s, c")
  end
end
