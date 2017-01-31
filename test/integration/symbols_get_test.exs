defmodule SymbolsGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router

  @opts Router.init([])

  @doc """
  GET /api/docs
  """
  test "list all symbols" do
    conn = conn(:get, "/api/docs")
    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols" => _symbols} = Poison.decode!(response.resp_body)
  end

  @doc """
  GET /api/docs?patches=all
  """
  test "Unauthenticated attempt at listing all patches for symbols" do
    conn = conn(:get, "/api/docs", %{"patches" => "all"})
    response = Router.call(conn, @opts)

    assert response.status == 401
  end

  @doc """
  GET /api/docs?patches=all -H 'authorization: at1'
  """
  test "Unauthorised attempt at listing all patches for symbols" do
    conn =
      conn(:get, "/api/docs", %{"patches" => "all"})
      |> put_req_header("authorization", "at1")

    response = Router.call(conn, @opts)

    assert response.status == 403
  end

  @doc """
  GET /api/docs?patches=all -H 'authorization: at2'
  """
  test "Authorised attempt 1 at listing all patches for symbols" do
    conn =
      conn(:get, "/api/docs", %{"patches" => "all"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_patches" => _patches, "symbols_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/docs?patches=all -H 'authorization: at3'
  """
  test "Authorised attempt 2 at listing all patches for symbols" do
    conn =
      conn(:get, "/api/docs", %{"patches" => "all"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_patches" => _patches, "symbols_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/docs?patches=insert -H 'authorization: at2'
  """
  test "Authorised attempt at listing all insert patches for symbols" do
    conn =
      conn(:get, "/api/docs", %{"patches" => "insert"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_inserts" => _inserts} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/docs?patches=update -H 'authorization: at2'
  """
  test "Authorised attempt at listing all update patches for symbols" do
    conn =
      conn(:get, "/api/docs", %{"patches" => "update"})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_updates" => _updates} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/docs?patches=delete -H 'authorization: at2'
  """
  test "Authorised attempt at listing all delete patches for symbols" do
    conn =
      conn(:get, "/api/docs", %{"patches" => "delete"})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status == 200
    assert %{"symbols_deletes" => _deletes} = Poison.decode! response.resp_body
  end
end
