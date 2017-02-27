defmodule PhpInternals.Api.Categories.CategoryController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Categories.Category
  alias PhpInternals.Utilities

  @default_limit 20
  @default_order_by "name"

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

  def index(conn, %{"patches" => "all"}) do
    all_categories_patches = Category.fetch_all_patches
    render(conn, "index_patches_all.json", categories_patches: all_categories_patches)
  end

  def index(conn, %{"patches" => "insert"}) do
    all_categories_patches_insert = Category.fetch_all_insert_patches
    render(conn, "index_patches_insert.json", categories_patches: all_categories_patches_insert)
  end

  def index(conn, %{"patches" => "update"}) do
    all_categories_patches_update = Category.fetch_all_update_patches
    render(conn, "index_patches_update.json", categories_patches: all_categories_patches_update)
  end

  def index(conn, %{"patches" => "delete"}) do
    all_categories_patches_delete = Category.fetch_all_delete_patches
    render(conn, "index_patches_delete.json", categories_patches: all_categories_patches_delete)
  end

  def index(conn, %{"patches" => _scope}) do
    conn
    |> put_status(404)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unknown patches type specified")
  end

  def index(%{user: %{privilege_level: 0}} = conn, %{"status" => "deleted"}) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def index(%{user: %{privilege_level: 3}} = conn, %{"status" => "deleted"}) do
    all_deleted_categories = Category.fetch_all_deleted
    render(conn, "index_normal.json", categories: all_deleted_categories)
  end

  def index(conn, %{"status" => "deleted"}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def index(conn, params) do
    with {:ok, view_type} <- Category.valid_view_type?(params["view"]),
         {:ok, order_by} <- Category.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
      all_categories = Category.fetch_all(view_type, order_by, ordering, offset, limit)
      render(conn, "index_#{view_type}.json", categories: all_categories)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(%{user: %{privilege_level: 0}} = conn, %{"category_name" => _url, "patches" => _scope}) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def show(%{user: %{privilege_level: 1}} = conn, %{"category_name" => _url, "patches" => _scope}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def show(conn, %{"category_name" => category_url, "patches" => "all"}) do
    with {:ok, _category} <- Category.valid?(category_url) do
      category_patches = Category.fetch_patches_for(category_url)
      render(conn, "index_patches_changes.json", category: category_patches)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"category_name" => category_url, "patches" => "insert"}) do
    category_patch_insert = Category.fetch_insert_patch_for(category_url)

    if category_patch_insert === nil do
      conn
      |> put_status(404)
      |> render(PhpInternals.ErrorView, "error.json", error: "Category insert not found")
    else
      render(conn, "show_insert.json", category: category_patch_insert)
    end
  end

  def show(conn, %{"category_name" => category_url, "patches" => "update", "patch_id" => patch_id}) do
    with {:ok, _category} <- Category.valid?(category_url) do
      category_patch_update = Category.fetch_update_patch_for(category_url, patch_id)

      if category_patch_update === nil do
        conn
        |> put_status(404)
        |> render(PhpInternals.ErrorView, "error.json", error: "Category update patch not found")
      else
        render(conn, "show_update.json", category: category_patch_update)
      end
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"category_name" => category_url, "patches" => "update"}) do
    with {:ok, _category} <- Category.valid?(category_url) do
      category_patches_update = Category.fetch_update_patches_for(category_url)

      if category_patches_update === nil do
        conn
        |> put_status(404)
        |> render(PhpInternals.ErrorView, "error.json", error: "Category update patches not found")
      else
        render(conn, "show_updates.json", category: category_patches_update)
      end
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"category_name" => category_url, "patches" => "delete"}) do
    with {:ok, _category} <- Category.valid?(category_url) do
      category_patch_delete = Category.fetch_delete_patch_for(category_url)

      if category_patch_delete === nil do
        conn
        |> put_status(404)
        |> render(PhpInternals.ErrorView, "error.json", error: "Category delete patch not found")
      else
        render(conn, "show_delete.json", category: category_patch_delete)
      end
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"category_name" => _category_url, "patches" => _scope}) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Invalid patch scope used")
  end

  def show(conn, %{"category_name" => category_url, "view" => "full"}) do
    with {:ok, _category} <- Category.valid?(category_url) do
      render(conn, "show_full.json", category: Category.fetch_full(category_url))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"category_name" => category_url, "view" => "overview"}) do
    with {:ok, category} <- Category.valid?(category_url) do
      render(conn, "show_overview.json", category: category)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"category_name" => _category_url, "view" => _view}) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Invalid category view used")
  end

  def show(conn, %{"category_name" => category_url}) do
    with {:ok, category} <- Category.valid?(category_url) do
      render(conn, "show.json", category: category)
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

  def create(%{user: %{privilege_level: 1}} = conn, %{"category" => %{}, "review" => review} = params) do
    with {:ok, _review} <- Utilities.valid_review_param?(review) do
      insert(conn, Map.put(params, "review", 1))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def create(%{user: %{privilege_level: 1}} = conn, %{"category" => %{}} = params) do
    insert(conn, Map.put(params, "review", 1))
  end

  def create(conn, %{"category" => %{}, "review" => review} = params) do
    with {:ok, review} <- Utilities.valid_review_param?(review) do
      insert(conn, Map.put(params, "review", review))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def create(conn, %{"category" => %{}} = params) do
    insert(conn, Map.put(params, "review", 0))
  end

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Malformed input data")
  end

  def update(%{user: %{privilege_level: 0}} = conn, %{"apply_patch" => _action, "category_name" => _category_url}) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: %{privilege_level: 1}} = conn, %{"apply_patch" => _action, "category_name" => _category_url}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def update(conn, %{"apply_patch" => action, "category_name" => category_url}) do
    with {:ok} <- Utilities.valid_patch_action?(action) do
      return = Category.accept_patch(category_url, action, conn.user.username)

      case return do
        {:ok, status_code} when is_integer(status_code) ->
          send_resp(conn, status_code, "")
        {:ok, category} ->
          render(conn, "show.json", category: category)
        {:error, status_code, message} ->
          conn
          |> put_status(status_code)
          |> render(PhpInternals.ErrorView, "error.json", error: message)
      end
    else
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
    end
  end

  def update(%{user: %{privilege_level: 0}} = conn, %{"discard_patch" => _action, "category_name" => _category_url}) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: %{privilege_level: 1}} = conn, %{"discard_patch" => _action, "category_name" => _category_url}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def update(conn, %{"discard_patch" => action, "category_name" => category_url}) do
    with {:ok} <- Utilities.valid_patch_action?(action) do
      return = Category.discard_patch(category_url, action, conn.user.username)

      case return do
        {:ok, status_code} ->
          send_resp(conn, status_code, "")
        {:error, status_code, message} ->
          conn
          |> put_status(status_code)
          |> render(PhpInternals.ErrorView, "error.json", error: message)
      end
    else
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
    end
  end

  def update(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: %{privilege_level: 1}} = conn, %{"category" => %{}, "review" => review} = params) do
    with {:ok, _review} <- Utilities.valid_review_param?(review) do
      modify(conn, Map.put(params, "review", 1))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def update(%{user: %{privilege_level: 1}} = conn, %{"category" => %{}} = params) do
    modify(conn, Map.put(params, "review", 1))
  end

  def update(conn, %{"category" => %{}, "review" => review} = params) do
    with {:ok, review} <- Utilities.valid_review_param?(review) do
      modify(conn, Map.put(params, "review", review))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
  end

  def update(conn, %{"category" => %{}} = params) do
    modify(conn, Map.put(params, "review", 0))
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

  def delete(%{user: %{privilege_level: 1}} = conn, %{"review" => review} = params) do
    with {:ok, _review} <- Utilities.valid_review_param?(review) do
      remove(conn, Map.put(params, "review", 1))
    else
      {:error, status_code, status} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: status)
    end
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

  defp insert(conn, %{"category" => category, "review" => review}) do
    with {:ok} <- Category.contains_required_fields?(category),
         {:ok} <- Category.contains_only_expected_fields?(category),
         {:ok, url_name} <- Utilities.is_url_friendly?(category["name"]),
         {:ok} <- Category.does_not_exist?(url_name) do
      category =
        category
        |> Map.put("url_name", url_name)
        |> Category.insert(review, conn.user.username)

      status_code = if review === 0, do: 201, else: 202

      conn
      |> put_status(status_code)
      |> render("show.json", category: category)
    else
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
    end
  end

  defp modify(conn, %{"category" => new_category, "category_name" => old_url, "review" => review} = params) do
    with {:ok} <- Category.contains_required_fields?(new_category),
         {:ok} <- Category.contains_only_expected_fields?(new_category),
         {:ok, new_url_name} <- Utilities.is_url_friendly?(new_category["name"]),
         {:ok, %{"category" => old_category}} <- Category.valid?(old_url) do
      new_category = Map.merge(new_category, %{"url" => new_url_name})

      new_category =
        if Map.has_key?(params, "references_patch") do
          if conn.user.privilege_level === 1 do
            {:error, 403, "Unauthorised action"}
          else
            Category.update(old_category, new_category, review, conn.user.username, params["references_patch"])
          end
        else
          Category.update(old_category, new_category, review, conn.user.username)
        end

      case new_category do
        {:error, status_code, error} ->
          conn
          |> put_status(status_code)
          |> render(PhpInternals.ErrorView, "error.json", error: error)
        {:ok, status_code, new_category} ->
          conn
          |> put_status(status_code)
          |> render("show.json", category: new_category)
      end
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  defp remove(conn, %{"category_name" => category_url, "review" => review}) do
    with {:ok, _category} <- Category.valid?(category_url),
         {:ok} <- Category.contains_no_symbols?(category_url) do
      Category.soft_delete(category_url, review, conn.user.username)

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
