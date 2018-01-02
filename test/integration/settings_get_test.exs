defmodule SettingsGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/settings
  """
  test "Unauthenticated list all settings" do
    conn = conn(:get, "/api/settings", %{})
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/settings -H 'authorization: at2'
  """
  test "Unauthorised list all settings" do
    conn =
      conn(:get, "/api/settings", %{})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 403
    assert %{"error" => %{"message" => "Unauthorised access attempt"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/settings -H 'authorization: at3'
  """
  test "list all settings" do
    conn =
      conn(:get, "/api/settings", %{})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"settings" => [%{"setting" => %{"cache_expiration_time" => _value}}]}
      = Poison.decode!(response.resp_body)
  end
end
