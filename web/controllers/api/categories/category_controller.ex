defmodule PhpInternals.Api.Categories.CategoryController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Categories.Category
  alias PhpInternals.Utilities
  alias PhpInternals.Api.Users.User
  alias PhpInternals.Stats.Counter

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
      render(conn, "index_patches_#{type}.json", categories_patches: Category.fetch_all_patches(type))
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
    with {:ok, order_by} <- Category.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
      Counter.exec(["incr", "visits:categories"])
      all_categories = Category.fetch_all_cache(order_by, ordering, offset, limit, params["search"], params["full_search"])
      send_resp(conn, 200, all_categories)
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
      render(conn, "index_patches_changes.json", category: Category.fetch_patches_for(category_url))
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

  # this has been deprecated in favour of /categories/{cat_name}/updates/{patch_id}
  def show(conn, %{"category_name" => category_url, "patches" => "update", "patch_id" => patch_id}) do
    with {:ok, _category} <- Category.valid?(category_url),
         {:ok, patch_id} <- Utilities.valid_id?(patch_id),
         {:ok, category_patch_update} <- Category.valid_update?(category_url, patch_id) do
        render(conn, "show_update.json", category: category_patch_update)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  # this has been deprecated in favour of /categories/{cat_name}/updates
  def show(conn, %{"category_name" => category_url, "patches" => "update"}) do
    with {:ok, _category} <- Category.valid?(category_url) do
      category_patches_update = Category.fetch_update_patches_for(category_url)
      render(conn, "show_updates.json", category: category_patches_update)
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

  def show(conn, %{"category_name" => category_url} = params) do
    with {:ok, view_type} <- Category.valid_show_view_type?(params["view"]),
         {:ok, category} <- Category.valid_cache?(category_url) do
      Counter.exec(["incr", "visits:categories:#{category_url}"])
      case view_type do
        "overview" -> send_resp(conn, 200, category)
        "normal" -> send_resp(conn, 200, Category.fetch_cache(category_url, "normal"))
      end
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show_updates(conn, %{"category_name" => category_url}) do
    show(conn, %{"category_name" => category_url, "patches" => "update"})
  end

  def show_update(conn, %{"category_name" => category_url, "update_id" => update_id}) do
    with {:ok, update_id} <- Utilities.valid_id?(update_id),
         {:ok, _category} <- Category.valid?(category_url),
         {:ok, category_update} <- Category.valid_update?(category_url, update_id) do
      render(conn, "show_update.json", category: category_update)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show_revisions(conn, %{"category_name" => category_url}) do
    with {:ok, _category} <- Category.valid?(category_url) do
      category_revisions = Category.fetch_revisions(category_url)
      render(conn, "show_revisions.json", category: category_revisions)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show_revision(conn, %{"category_name" => category_url, "revision_id" => revision_id}) do
    with {:ok, revision_id} <- Utilities.valid_id?(revision_id),
         {:ok, _category} <- Category.valid?(category_url),
         {:ok, category_revision} <- Category.valid_revision?(category_url, revision_id) do
      render(conn, "show_revision.json", category: category_revision)
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

  def update(%{user: %{privilege_level: 0}} = conn, _params) do
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
    with {:ok, action} <- Utilities.valid_patch_action?(action),
         {:ok, return} <- Category.apply_patch?(category_url, action, conn.user.username) do
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

  def update(%{user: %{privilege_level: 1}} = conn, %{"discard_patch" => _action, "category_name" => _category_url}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def update(conn, %{"discard_patch" => action, "category_name" => category_url}) do
    with {:ok, action} <- Utilities.valid_patch_action?(action),
         {:ok, return} <- Category.discard_patch?(category_url, action, conn.user.username) do
      send_resp(conn, return, "")
    else
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
    end
  end

  def update(%{user: user} = conn, %{"category" => %{}, "review" => review, "revision_id" => _rev_id} = params) do
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

  def update(conn, %{"category" => %{}} = params) do
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
    with {:ok} <- User.within_patch_limit?(conn.user),
         {:ok, category} <- Category.valid_fields?(category),
         {:ok, url} <- Utilities.is_url_friendly?(category["name"]),
         {:ok} <- Category.does_not_exist?(url),
         {:ok} <- Category.valid_linked_categories?(category["subcategories"], category["supercategories"], url) do
      category =
        category
        |> Map.put("url", url)
        |> Category.insert(review, conn.user.username)

      if review === 0 do
        send_resp(conn, 201, category)
      else
        send_resp(conn, 202, "")
      end
    else
      {:error, status_code, message} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: message)
    end
  end

  defp modify(%{user: %{privilege_level: 1}} = conn, %{"category" => _, "category_name" => _, "references_patch" => _}) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised action")
  end

  defp modify(conn, %{"category" => new_category, "category_name" => old_url, "review" => review, "revision_id" => rev_id} = params) do
    with {:ok} <- User.within_patch_limit?(conn.user),
         {:ok, new_category} <- Category.valid_fields?(new_category),
         {:ok, new_url} <- Utilities.is_url_friendly?(new_category["name"]),
         {:ok} <- Category.does_not_exist?(new_url, old_url),
         {:ok, %{"category" => old_category}} <- Category.valid_and_fetch?(old_url),
         {:ok, refs_patch} <- Utilities.valid_optional_id?(params["references_patch"]),
         {:ok} <- Category.update_patch_exists?(old_url, refs_patch),
         {:ok} <- Utilities.revision_ids_match?(rev_id, refs_patch || old_category["revision_id"]),
         {:ok} <- Category.valid_linked_categories?(new_category["subcategories"], new_category["supercategories"], old_url) do
      new_category = Map.merge(new_category, %{"url" => new_url})
      new_category = Category.update(old_category, new_category, review, conn.user.username, refs_patch)
      status_code = if review === 0, do: 200, else: 202
      send_resp(conn, status_code, new_category)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  defp remove(conn, %{"category_name" => category_url, "review" => review}) do
    with {:ok} <- User.within_patch_limit?(conn.user),
         {:ok, %{"category" => category}} <- Category.valid_and_fetch?(category_url),
         {:ok} <- Category.contains_nothing?(category_url),
         {:ok} <- Category.has_no_delete_patch?(category_url) do
      Category.soft_delete(category, review, conn.user.username)

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
