defmodule PhpInternals.Api.Symbols.SymbolController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Categories.Category
  alias PhpInternals.Api.Symbols.Symbol
  alias PhpInternals.Utilities

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

  def index(conn, %{"patches" => scope}) do
    case scope do
      "all" ->
        render(conn, "index_patches_all.json", symbols_patches: Symbol.fetch_all_symbols_patches)
      "insert" ->
        render(conn, "index_patches_insert.json", symbols_patches: Symbol.fetch_all_symbols_patches_insert)
      "update" ->
        render(conn, "index_patches_update.json", symbols_patches: Symbol.fetch_all_symbols_patches_update)
      "delete" ->
        render(conn, "index_patches_delete.json", symbols_patches: Symbol.fetch_all_symbols_patches_delete)
      _ ->
        conn
        |> put_status(404)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unknown patches type specified")
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
    render(conn, "index_deleted.json", symbols: Symbol.fetch_all_symbols_deleted)
  end

  def index(conn, params) do
    with {:ok, order_by} <- Symbol.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]),
         {:ok, symbol_type} <- Symbol.valid_symbol_type?(params["type"]),
         {:ok, _category} <- Category.valid_category?(params["category"]) do
        #  {:ok, search_term} <- Symbol.valid_search?(params["search"]) do
      render(conn, "index.json", symbols: Symbol.fetch_all_symbols(order_by, ordering, offset, limit, symbol_type, params["category"], params["search"]))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_id" => symbol_id, "view" => "overview"}) do
    fetch(conn, symbol_id, "overview")
  end

  def show(conn, %{"view" => _view}) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unknown view type")
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
         {:ok, _symbol} <- Symbol.symbol_exists?(symbol_id),
         {:ok, symbol} <- Symbol.is_delete_patch?(symbol_id) do
      render(conn, "show_delete.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_id" => symbol_id, "patches" => "update", "patch_id" => patch_id}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, _symbol} <- Symbol.symbol_exists?(symbol_id),
         {:ok, symbol} <- Symbol.update_patch_exists?(symbol_id, String.to_integer(patch_id)) do
      render(conn, "show_update.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_id" => symbol_id, "patches" => "update"}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, _symbol} <- Symbol.symbol_exists?(symbol_id) do
      render(conn, "show_updates.json", symbol: Symbol.fetch_symbol_update_patches(symbol_id))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_id" => symbol_id, "patches" => "all"}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, symbol} <- Symbol.has_patches?(symbol_id) do
      render(conn, "show_patches_changes.json", symbol: symbol)
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

  def show(conn, %{"symbol_id" => symbol_id}) do
    fetch(conn, symbol_id, "normal")
  end

  defp fetch(conn, symbol_id, view) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, symbol} <- Symbol.fetch(symbol_id, view) do
      case view do
        "normal" -> render(conn, "show.json", symbol: symbol)
        "overview" -> render(conn, "show_overview.json", symbol: symbol)
      end
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def create(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def create(conn, params) do
    review =
      cond do
        conn.user.privilege_level === 1 -> 1
        Map.has_key?(params, "review") -> String.to_integer(params["review"])
        true -> 0
      end

    insert(conn, Map.put(params, "review", review))
  end

  defp insert(conn, %{"symbol" => symbol, "review" => review}) do
    with {:ok} <- Symbol.contains_required_fields?(symbol),
         {:ok} <- Symbol.contains_only_expected_fields?(symbol),
         {:ok} <- Category.valid_categories?(symbol["categories"]),
         {:ok} <- Utilities.valid_review_param?(review) do
      url_name = Utilities.make_url_friendly_name(symbol["name"])

      symbol =
        symbol
        |> Map.merge(%{"url" => url_name})
        |> Symbol.insert(review)

      status_code = if review === 0, do: 201, else: 202

      conn
      |> put_status(status_code)
      |> render("symbol.json", symbol: symbol)
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  defp insert(conn, _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Bad request data format")
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
         {:ok, return} <- Symbol.accept_symbol_patch(symbol_id, action) do
      if is_integer(return) do
        send_resp(conn, return, "")
      else
        render(conn, "show.json", symbol: return)
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
         {:ok, status_code} <- Symbol.discard_symbol_patch(symbol_id, action) do
      send_resp(conn, status_code, "")
    else
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
    end
  end

  def update(conn, params) do
    review =
      cond do
        conn.user.privilege_level === 1 -> 1
        Map.has_key?(params, "review") -> String.to_integer(params["review"])
        true -> 0
      end

    modify(conn, Map.put(params, "review", review))
  end

  defp modify(%{user: %{privilege_level: 1}} = conn, %{"references_patch" => _refs_patch}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  defp modify(conn, %{"symbol" => %{} = symbol, "symbol_id" => symbol_id, "review" => review} = params) do
    with {:ok} <- Symbol.contains_required_fields?(symbol),
         {:ok} <- Symbol.contains_only_expected_fields?(symbol),
         {:ok} <- Category.valid_categories?(symbol["categories"]),
         {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, old_symbol} <- Symbol.symbol_exists?(symbol_id),
         {:ok} <- Utilities.valid_review_param?(review) do
      url_name = Utilities.make_url_friendly_name(symbol["name"])

      symbol = Map.merge(symbol, %{"url" => url_name})

      symbol =
        if Map.has_key?(params, "references_patch") do
          Symbol.update(symbol, old_symbol["symbol"], review, params["references_patch"])
        else
          Symbol.update(symbol, old_symbol["symbol"], review)
        end

      status_code = if review === 0, do: 200, else: 202

      conn
      |> put_status(status_code)
      |> render("show.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  defp modify(conn, _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Bad request data format")
  end

  def delete(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def delete(conn, params) do
    review =
      cond do
        conn.user.privilege_level === 1 -> 1
        Map.has_key?(params, "review") -> String.to_integer(params["review"])
        true -> 0
      end

    remove(conn, Map.put(params, "review", review))
  end

  defp remove(%{user: %{privilege_level: 3}} = conn, %{"symbol_id" => symbol_id, "mode" => "hard"}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, _symbol} <- Symbol.is_deleted?(symbol_id) do
      Symbol.hard_delete_symbol(symbol_id)

      conn
      |> send_resp(204, "")
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  defp remove(%{user: %{privilege_level: _pl}} = conn, %{"mode" => "hard"}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  defp remove(conn, %{"symbol_id" => symbol_id, "review" => review}) do
    with {:ok, symbol_id} <- Utilities.valid_id?(symbol_id),
         {:ok, _symbol} <- Symbol.symbol_exists?(symbol_id),
         {:ok} <- Utilities.valid_review_param?(review) do
      Symbol.soft_delete_symbol(symbol_id, review)

      status_code = if review == 0, do: 204, else: 202

      conn
      |> send_resp(status_code, "")
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end
end
