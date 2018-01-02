defmodule SettingPatchTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use PhpInternals.ConnCase

  test "Unauthenticated setting update" do
    conn = conn(:patch, "/api/settings/a")
    response = Router.call(conn, @opts)

    assert response.status === 401
    assert %{"error" => %{"message" => "Unauthenticated access attempt"}} = Poison.decode! response.resp_body
  end

  test "Unauthorised setting update" do
    conn =
      conn(:patch, "/api/settings/a")
      |> put_req_header("authorization", "at2")

    response = Router.call(conn, @opts)

    assert response.status === 403
    assert %{"error" => %{"message" => "Unauthorised access attempt"}} = Poison.decode! response.resp_body
  end

  test "Invalid input data" do
    conn =
      conn(:patch, "/api/settings/cache_expiration_time", %{"v" => 1})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 400
    assert %{"error" => %{"message" => "Invalid input format"}} = Poison.decode! response.resp_body
  end

  test "Updating a setting" do
    conn =
      conn(:patch, "/api/settings/cache_expiration_time", %{"value" => 1})
      |> put_req_header("authorization", "at3")

    response = Router.call(conn, @opts)

    assert response.status === 200
    assert %{"setting" => %{"cache_expiration_time" => 1}} = Poison.decode! response.resp_body
  end
end
