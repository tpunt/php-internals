defmodule CategoriesGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/categories
  """
  test "list all categories overview" do
    conn = conn(:get, "/api/categories", %{})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories" => _categories} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/categories?search=xiSten
  """
  test "search all categories by name" do
    conn = conn(:get, "/api/categories", %{"search" => "xiSten"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories" => categories} = Poison.decode!(response.resp_body)
    assert %{"category" => %{"name" => "existent"}} = List.first categories
  end

  @doc """
  GET /api/categories?search==exiStent
  """
  test "search all categories by exact name" do
    conn = conn(:get, "/api/categories", %{"search" => "=exiStent"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories" => categories} = Poison.decode!(response.resp_body)
    assert %{"category" => %{"name" => "existent"}} = List.first categories
  end

  @doc """
  GET /api/categories?search==xiSten
  """
  test "search all categories by exact name (no results)" do
    conn = conn(:get, "/api/categories", %{"search" => "=xiSten"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories" => []} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/categories?search=~&full_search=true
  """
  test "search all categories by body" do
    conn = conn(:get, "/api/categories", %{"search" => "~", "full_search" => "1"})
    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories" => categories} = Poison.decode!(response.resp_body)
    assert %{"category" => %{}} = List.first categories
  end

  @doc """
  GET /api/categories?patches=all
  """
  test "Unauthenticated attempt at listing all patches for categories" do
    conn = conn(:get, "/api/categories", %{"patches" => "all"})
    response = Router.call(conn, @opts)

    assert response.status === 401
  end

  @doc """
  GET /api/categories?patches=all -H 'authorization: at1'
  """
  test "Unauthorised attempt at listing all patches for categories" do
    conn =
      conn(:get, "/api/categories", %{"patches" => "all"})
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status === 403
  end

  @doc """
  GET /api/categories?patches=all -H 'authorization: at2'
  """
  test "Authorised attempt 1 at listing all patches for categories" do
    conn =
      conn(:get, "/api/categories", %{"patches" => "all"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories_patches" => _patches, "categories_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories?patches=all -H 'authorization: at3'
  """
  test "Authorised attempt 2 at listing all patches for categories" do
    conn =
      conn(:get, "/api/categories", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories_patches" => _patches, "categories_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories?patches=insert -H 'authorization: at2'
  """
  test "Authorised attempt at listing all insert patches for categories" do
    conn =
      conn(:get, "/api/categories", %{"patches" => "insert"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories?patches=update -H 'authorization: at2'
  """
  test "Authorised attempt at listing all update patches for categories" do
    conn =
      conn(:get, "/api/categories", %{"patches" => "update"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories_updates" => _updates} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories?patches=delete -H 'authorization: at2'
  """
  test "Authorised attempt at listing all delete patches for categories" do
    conn =
      conn(:get, "/api/categories", %{"patches" => "delete"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories_deletes" => _deletes} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/categories?status=deleted -H 'authorization: at2'
  """
  test "Unauthorised attempt at viewing deleted categories" do
    conn =
      conn(:get, "/api/categories", %{"status" => "deleted"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 403
  end

  @doc """
  GET /api/categories?status=deleted -H 'authorization: at3'
  """
  test "Authorised attempt at viewing deleted categories" do
    conn =
      conn(:get, "/api/categories", %{"status" => "deleted"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"categories" => _categories} = Poison.decode!(response.resp_body)
  end
end
