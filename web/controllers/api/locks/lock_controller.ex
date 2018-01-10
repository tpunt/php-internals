defmodule PhpInternals.Api.Locks.LockController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Locks.Lock
  # alias PhpInternals.Api.Locks.LockView

  def update(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: user} = conn, %{"lock" => lock_type, "revision_id" => revision_id}) do
    with {:ok} <- Lock.valid_lock_type?(lock_type, conn.user.privilege_level),
         {:ok} <- Lock.attempt(lock_type, revision_id, user.username, user.privilege_level) do
      send_resp(conn, 200, "")
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def update(conn, _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "A 'lock' parameter must be given")
  end
end
