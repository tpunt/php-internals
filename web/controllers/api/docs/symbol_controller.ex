defmodule PhpInternals.Api.Docs.SymbolController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Docs.Category
  alias PhpInternals.Api.Docs.Symbol
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
        all_symbols_patches = Symbol.fetch_all_symbols_patches
        render(conn, "index_patches_all.json", symbols_patches: all_symbols_patches)
      "insert" ->
        all_symbols_patches_insert = Symbol.fetch_all_symbols_patches_insert
        render(conn, "index_patches_insert.json", symbols_patches: all_symbols_patches_insert)
      "update" ->
        all_symbols_patches_update = Symbol.fetch_all_symbols_patches_update
        render(conn, "index_patches_update.json", symbols_patches: all_symbols_patches_update)
      "delete" ->
        all_symbols_patches_delete = Symbol.fetch_all_symbols_patches_delete
        render(conn, "index_patches_delete.json", symbols_patches: all_symbols_patches_delete)
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
    all_deleted_symbols = Symbol.fetch_all_symbols_deleted
    render(conn, "index_deleted.json", symbols: all_deleted_symbols)
  end

  def index(conn, params) do
    with {:ok, order_by} <- Symbol.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
      render(conn, "index.json", symbols: Symbol.fetch_all_symbols(order_by, ordering, offset, limit))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_name" => symbol_url, "view" => "overview"}) do
    fetch(conn, symbol_url, "overview")
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

  def show(conn, %{"symbol_name" => symbol_url, "patches" => "insert"}) do
    with {:ok, symbol} <- Symbol.is_insert_patch?(symbol_url) do
      render(conn, "show_insert.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_name" => symbol_url, "patches" => "delete"}) do
    with {:ok, _symbol} <- Symbol.symbol_exists?(symbol_url),
         {:ok, symbol} <- Symbol.is_delete_patch?(symbol_url) do
      render(conn, "show_delete.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_name" => symbol_url, "patches" => "update", "patch_id" => patch_id}) do
    with {:ok, _symbol} <- Symbol.symbol_exists?(symbol_url),
         {:ok, symbol} <- Symbol.update_patch_exists?(symbol_url, String.to_integer(patch_id)) do
      render(conn, "show_update.json", symbol: symbol)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_name" => symbol_url, "patches" => "update"}) do
    with {:ok, _symbol} <- Symbol.symbol_exists?(symbol_url) do
      symbol_patches_update = Symbol.fetch_symbol_update_patches(symbol_url)

      render(conn, "show_updates.json", symbol: symbol_patches_update)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"symbol_name" => symbol_url, "patches" => "all"}) do
    with {:ok, symbol} <- Symbol.has_patches?(symbol_url) do
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

  def show(conn, %{"symbol_name" => symbol_name}) do
    fetch(conn, symbol_name, "normal")
  end

  defp fetch(conn, symbol_name, view) do
    symbol = Symbol.fetch(symbol_name, view)

    case symbol do
      {:ok, symbol} ->
        case view do
          "normal" -> render(conn, "show.json", symbol: symbol)
          "overview" -> render(conn, "show_overview.json", symbol: symbol)
        end
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

  def update(conn, %{"symbol_name" => symbol_url, "apply_patch" => action}) do
    symbol = Symbol.accept_symbol_patch(symbol_url, action)

    case symbol do
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
      {:ok, status_code} when is_integer(status_code) ->
        conn
        |> send_resp(status_code, "")
      {:ok, symbol} ->
        render(conn, "show.json", symbol: symbol)
    end
  end

  def update(%{user: %{privilege_level: 1}} = conn, %{"discard_patch" => _action}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def update(conn, %{"symbol_name" => symbol_url, "discard_patch" => action}) do
    return = Symbol.discard_symbol_patch(symbol_url, action)

    case return do
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
      {:ok, status_code} ->
        conn
        |> send_resp(status_code, "")
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

  defp modify(conn, %{"symbol" => %{} = symbol, "symbol_name" => old_url, "review" => review} = params) do
    with {:ok} <- Symbol.contains_required_fields?(symbol),
         {:ok} <- Symbol.contains_only_expected_fields?(symbol),
         {:ok} <- Category.valid_categories?(symbol["categories"]),
         {:ok, old_symbol} <- Symbol.symbol_exists?(old_url),
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

  defp remove(%{user: %{privilege_level: 3}} = conn, %{"symbol_name" => symbol_url, "mode" => "hard"}) do
    with {:ok, _symbol} <- Symbol.is_deleted?(symbol_url) do
      Symbol.hard_delete_symbol(symbol_url)

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

  defp remove(conn, %{"symbol_name" => url_name, "review" => review}) do
    with {:ok, _symbol} <- Symbol.symbol_exists?(url_name),
         {:ok} <- Utilities.valid_review_param?(review) do
      Symbol.soft_delete_symbol(url_name, review)

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
