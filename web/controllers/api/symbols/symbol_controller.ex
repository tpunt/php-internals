defmodule PhpInternals.Api.Symbols.SymbolController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Categories.Category
  alias PhpInternals.Api.Symbols.Symbol
  alias PhpInternals.Api.Users.User
  alias PhpInternals.Utilities
  alias PhpInternals.Stats.Counter
  alias PhpInternals.Api.Settings.Setting
  alias PhpInternals.Api.Locks.Lock

  def index(%{user: %{privilege_level: 0}} = conn, %{"patches" => _scope}) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def index(%{user: %{privilege_level: 1}} = conn, %{"patches" => _scope}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def index(conn, %{"patches" => type}) do
    with {:ok} <- Utilities.valid_patch_type?(type) do
      render(conn, "index_patches_#{type}.json", symbols_patches: Symbol.fetch_all_patches(type))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def index(%{user: %{privilege_level: 0}} = conn, %{"status" => "deleted"}) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def index(%{user: %{privilege_level: pl}} = conn, %{"status" => "deleted"}) when pl in [1, 2] do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def index(conn, %{"status" => "deleted"}) do
    render(conn, "index_deleted.json", symbols: Symbol.fetch_all_deleted)
  end

  def index(conn, params) do
    with {:ok, order_by} <- Symbol.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]),
         {:ok, type} <- Symbol.valid_type?(params["type"]),
         {:ok, _category} <- Category.valid_cache?(params["category"]) do
      Counter.exec(["incr", "visits:symbols"])

      conn
      |> put_resp_header("cache-control", "max-age=#{Setting.get("cache_expiration_time")}, public")
      |> send_resp(200, Symbol.fetch_all_cache(order_by, ordering, offset, limit, type, params["category"], params["search"], params["full_search"]))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(%{user: %{privilege_level: 0}} = conn, %{"patches" => _scope}) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def show(%{user: %{privilege_level: 1}} = conn, %{"patches" => _scope}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def show(conn, %{"symbol_id" => symbol_id, "patches" => "insert"}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, symbol} <- Symbol.is_insert_patch?(symbol_id) do
      render(conn, "show_insert.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_id" => symbol_id, "patches" => "delete"}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, _symbol} <- Symbol.valid_cache?(symbol_id),
         {:ok, symbol} <- Symbol.has_delete_patch?(symbol_id) do
      render(conn, "show_delete.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  # this has been deprecated in favour of /symbols/{sym_id}/updates/{patch_id}
  def show(conn, %{"symbol_id" => symbol_id, "patches" => "update", "patch_id" => patch_id}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, patch_id} <- Utilities.valid_id?(patch_id),
         {:ok, _symbol} <- Symbol.valid_cache?(symbol_id),
         {:ok, symbol} <- Symbol.update_patch_exists?(symbol_id, patch_id) do
      render(conn, "show_specific_update.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  # this has been deprecated in favour of /symbols/{sym_id}/updates
  def show(conn, %{"symbol_id" => symbol_id, "patches" => "update"}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, _symbol} <- Symbol.valid_cache?(symbol_id) do
      render(conn, "show_updates.json", symbol: Symbol.fetch_update_patches_for(symbol_id))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_id" => symbol_id, "patches" => "all"}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id) do
      render(conn, "show_patches_changes.json", symbol: Symbol.fetch_all_patches_for(symbol_id))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"patches" => _type}) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unknown patch type specified")
  end

  def show(conn, %{"symbol_id" => symbol_id} = params) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, view_type} <- Symbol.valid_view_type?(params["view"]),
         {:ok, symbol} <- Symbol.valid_cache?(symbol_id) do
      Counter.exec(["incr", "visits:symbols:#{symbol_id}"])

      if view_type === "overview" do
        conn
        |> put_resp_header("cache-control", "max-age=#{Setting.get("cache_expiration_time")}, public")
        |> send_resp(200, symbol)
      else
        conn
        |> put_resp_header("cache-control", "max-age=#{Setting.get("cache_expiration_time")}, public")
        |> send_resp(200, Symbol.fetch_cache(symbol_id, view_type))
      end
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def show_updates(conn, %{"symbol_id" => symbol_id}) do
    show(conn, %{"symbol_id" => symbol_id, "patches" => "update"})
  end

  def show_update(conn, %{"symbol_id" => symbol_id, "update_id" => update_id}) do
    show(conn, %{"symbol_id" => symbol_id, "patches" => "update", "patch_id" => update_id})
  end

  def show_revisions(conn, %{"symbol_id" => symbol_id}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id) do
      symbol_revisions = Symbol.fetch_revisions(symbol_id)
      render(conn, "show_revisions.json", symbol: symbol_revisions)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show_revision(conn, %{"symbol_id" => symbol_id, "revision_id" => revision_id}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, revision_id} <- Utilities.valid_id?(revision_id),
         {:ok, _symbol} <- Symbol.valid?(symbol_id),
         {:ok, symbol_revision} <- Symbol.valid_revision?(symbol_id, revision_id) do
      render(conn, "show_revision.json", symbol: symbol_revision)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def create(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def create(%{user: %{privilege_level: 1}} = conn, %{"symbol" => %{}, "review" => review} = params) do
    with {:ok, _review} <- Utilities.valid_review_param?(review) do
      insert(conn, Map.put(params, "review", 1))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def create(%{user: %{privilege_level: 1}} = conn, %{"symbol" => %{}} = params) do
    insert(conn, Map.put(params, "review", 1))
  end

  def create(conn, %{"symbol" => %{}, "review" => review} = params) do
    with {:ok, review} <- Utilities.valid_review_param?(review) do
      insert(conn, Map.put(params, "review", review))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def create(conn, %{"symbol" => %{}} = params) do
    insert(conn, Map.put(params, "review", 0))
  end

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Malformed input data")
  end

  def update(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: %{privilege_level: 1}} = conn, %{"apply_patch" => _action}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def update(conn, %{"symbol_id" => symbol_id, "apply_patch" => action}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, action} <- Utilities.valid_patch_action?(action),
         {:ok, return} <- Symbol.apply_patch?(symbol_id, action, conn.user.username) do
      if is_integer(return) do
        send_resp(conn, return, "")
      else
        send_resp(conn, 200, return)
      end
    else
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
    end
  end

  def update(%{user: %{privilege_level: 1}} = conn, %{"discard_patch" => _action}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def update(conn, %{"symbol_id" => symbol_id, "discard_patch" => action}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, action} <- Utilities.valid_patch_action?(action),
         {:ok, status_code} <- Symbol.discard_patch?(symbol_id, action, conn.user.username) do
      send_resp(conn, status_code, "")
    else
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
    end
  end

  def update(%{user: user} = conn, %{"symbol" => %{}, "review" => review, "revision_id" => _rev_id} = params) do
    with {:ok, review} <- Utilities.valid_review_param?(review) do
      review = if user.privilege_level === 1, do: 1, else: review
      modify(conn, Map.put(params, "review", review))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def update(conn, %{"symbol" => %{}} = params) do
    if Map.has_key?(params, "revision_id") do
      update(conn, Map.put(params, "review", 0))
    else
      conn
      |> put_status(400)
      |> render(PhpInternals.ErrorView, "error.json", error: "A revision ID must be specified")
    end
  end

  def update(conn, _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Malformed input data")
  end

  def delete(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def delete(%{user: %{privilege_level: 1}} = conn, params) do
    remove(conn, Map.put(params, "review", 1))
  end

  def delete(conn, %{"review" => review} = params) do
    with {:ok, review} <- Utilities.valid_review_param?(review) do
      remove(conn, Map.put(params, "review", review))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def delete(conn, params) do
    remove(conn, Map.put(params, "review", 0))
  end

  defp insert(conn, %{"symbol" => symbol, "review" => review}) do
    with {:ok} <- User.within_patch_limit?(conn.user),
         {:ok, symbol} <- Symbol.valid_fields?(symbol),
         {:ok, url_name} <- Utilities.is_url_friendly?(symbol["name"]),
         {:ok} <- Category.all_valid?(symbol["categories"]) do
      symbol =
        symbol
        |> Map.merge(%{"url" => url_name})
        |> Symbol.insert(review, conn.user.username)

      if review === 0 do
        send_resp(conn, 201, symbol)
      else
        send_resp(conn, 202, "")
      end
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  defp modify(%{user: %{privilege_level: 1}} = conn, %{"category" => _, "category_name" => _, "references_patch" => _}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised action")
  end

  defp modify(conn, %{"symbol" => symbol, "symbol_id" => symbol_id, "review" => review, "revision_id" => rev_id} = params) do
    with {:ok} <- User.within_patch_limit?(conn.user),
         {:ok, symbol} <- Symbol.valid_fields?(symbol),
         {:ok, url_name} <- Utilities.is_url_friendly?(symbol["name"]),
         {:ok} <- Category.all_valid?(symbol["categories"]),
         {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, %{"symbol" => old_symbol}} <- Symbol.valid?(symbol_id),
         {:ok, refs_patch} <- Utilities.valid_optional_id?(params["references_patch"]),
         {:ok} <- Utilities.revision_ids_match?(rev_id, refs_patch || old_symbol["revision_id"]),
         {:ok} <- Lock.has_lock?(old_symbol["revision_id"], conn.user.username),
         {:ok} <- Lock.has_lock?(refs_patch, conn.user.username) do
      symbol = Map.merge(symbol, %{"url" => url_name})
      symbol = Symbol.update(old_symbol, symbol, review, conn.user.username, refs_patch)

      case symbol do
        {:error, status_code, error} ->
          conn
          |> put_status(status_code)
          |> render(PhpInternals.ErrorView, "error.json", error: error)
        {:ok, status_code, symbol} ->
          send_resp(conn, status_code, symbol)
      end
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  defp remove(conn, %{"symbol_id" => symbol_id, "review" => review}) do
    with {:ok} <- User.within_patch_limit?(conn.user),
         {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, %{"symbol" => symbol}} <- Symbol.valid?(symbol_id),
         {:ok} <- Symbol.has_no_delete_patch?(symbol_id),
         {:ok} <- Lock.has_lock?(symbol["revision_id"], conn.user.username) do
      Symbol.soft_delete(symbol_id, review, conn.user.username)

      status_code = if review == 0, do: 204, else: 202
      send_resp(conn, status_code, "")
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end
end
