defmodule CategoriesGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router

  @opts Router.init([])

  @doc """
  GET /api/categories
  """
  test "list all categories" do
    conn = conn(:get, "/api/categories", %{})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"categories" => _categories} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/categories?view=overview
  """
  test "list all categories overview" do
    conn = conn(:get, "/api/categories", %{"view" => "overview"})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"categories" => _categories} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/categories?view=full
  """
  test "list all categories in full" do
    conn = conn(:get, "/api/categories", %{"view" => "full"})
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"categories" => _categories} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/categories?patches=all
  """
  test "Unauthenticated attempt at listing all patches for categories" do
    conn = conn(:get, "/api/categories", %{"patches" => "all"})
    response = Router.call(conn, @opts)

    assert response.status == 401
  end

  @doc """
  GET /api/categories?patches=all -H 'authorization: at1'
  """
  test "Unauthorised attempt at listing all patches for categories" do
    conn =
      conn(:get, "/api/categories", %{"patches" => "all"})
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 403
  end

  @doc """
  GET /api/categories?patches=all -H 'authorization: at2'
  """
  test "Authorised attempt 1 at listing all patches for categories" do
    conn =
      conn(:get, "/api/categories", %{"patches" => "all"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
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

    assert response.status == 200
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

    assert response.status == 200
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

    assert response.status == 200
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

    assert response.status == 200
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

    assert response.status == 403
  end

  @doc """
  GET /api/categories?status=deleted -H 'authorization: at3'
  """
  test "Authorised attempt at viewing deleted categories" do
    conn =
      conn(:get, "/api/categories", %{"status" => "deleted"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"categories" => _categories} = Poison.decode!(response.resp_body)
  end
end
