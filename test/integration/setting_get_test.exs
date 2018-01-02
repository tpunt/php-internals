defmodule SettingGetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  @doc """
  GET /api/settings/setting_name
  """
  test "Unauthenticated list a settings" do
    conn = conn(:get, "/api/settings/setting_name", %{})
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/settings/setting_name -H 'authorization: at2'
  """
  test "Unauthorised list a settings" do
    conn =
      conn(:get, "/api/settings/setting_name", %{})
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 403
    assert %{"error" => %{"message" => "Unauthorised access attempt"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/settings/setting_name -H 'authorization: at2'
  """
  test "List an invalid setting name" do
    conn =
      conn(:get, "/api/settings/invalid_setting_name", %{})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Invalid setting name"}} = Poison.decode! response.resp_body
  end

  @doc """
  GET /api/settings -H 'authorization: at3'
  """
  test "List a setting" do
    conn =
      conn(:get, "/api/settings/cache_expiration_time", %{})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"setting" => %{"cache_expiration_time" => _value}}
      = Poison.decode!(response.resp_body)
  end
end
