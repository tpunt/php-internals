defmodule SymbolsGetTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias PhpInternals.Router

  @opts Router.init([])

  @doc """
  GET /api/symbols
  """
  test "list all symbols" do
    conn = conn(:get, "/api/symbols")
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
end
