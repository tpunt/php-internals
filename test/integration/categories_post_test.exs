defmodule CategoriesPostTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router
  alias Neo4j.Sips, as: Neo4j

  @opts Router.init([])

  @doc """
  POST /api/docs/categories
  """
  test "Unauthenticated attempt at inserting a new category" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/docs/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")

    response = Router.call(conn, @opts)

    assert response.status == 401
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")
  end

  @doc """
  POST /api/docs/categories -H 'authorization: at1'
  """
  test "Authorised attempt 1 at inserting a new category patch" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/docs/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 202
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'}) DELETE c")
  end

  @doc """
  POST /api/docs/categories?review=1 -H 'authorization: at2'
  """
  test "Authorised attempt 2 at inserting a new category patch" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/docs/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}, "review" => "1"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 202
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'}) DELETE c")
  end

  @doc """
  POST /api/docs/categories?review=1 -H 'authorization: at3'
  """
  test "Authorised attempt 3 at inserting a new category patch" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/docs/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}, "review" => "1"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 202
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'}) DELETE c")
  end

  @doc """
  POST /api/docs/categories?review=1 -H 'authorization: at3'
  """
  test "Authorised invalid attempt at inserting a new category patch" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/docs/categories", %{"category" => %{"introduction": "..."}, "review" => "1"})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 400
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:InsertCategoryPatch {name: '#{name}'}) RETURN c")
  end

  @doc """
  POST /api/docs/categories -H 'authorization: at2'
  """
  test "Authorised attempt 1 at inserting a new category" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/docs/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 201
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) DELETE c")
  end

  @doc """
  POST /api/docs/categories -H 'authorization: at3'
  """
  test "Authorised attempt 2 at inserting a new category" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/docs/categories", %{"category" => %{"name": "#{name}", "introduction": "..."}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 201
    refute [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")

    Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) DELETE c")
  end

  @doc """
  POST /api/docs/categories -H 'authorization: at3'
  """
  test "Authorised invalid attempt at inserting a new category" do
    name = :rand.uniform(100_000_000)
    conn =
      conn(:post, "/api/docs/categories", %{"category" => %{"name": "#{name}"}})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 400
    assert [] == Neo4j.query!(Neo4j.conn, "MATCH (c:Category {name: '#{name}'}) RETURN c")
  end
end
