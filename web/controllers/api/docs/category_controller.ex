defmodule PhpInternals.Api.Docs.CategoryController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Docs.Category
  alias PhpInternals.Utilities

  @default_limit 20
  @default_order_by "name"

  def index(conn, %{"patches" => scope}) do
    cond do
      conn.user.privilege_level == 0 ->
        conn
        |> put_status(401)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
      conn.user.privilege_level == 1 ->
        conn
        |> put_status(403)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
      conn.user.privilege_level > 1 ->
        case scope do
          "all" ->
            all_categories_patches = Category.fetch_all_categories_patches
            render(conn, "index_patches_all.json", categories_patches: all_categories_patches)
          "insert" ->
            all_categories_patches_insert = Category.fetch_all_categories_patches_insert
            render(conn, "index_patches_insert.json", categories_patches: all_categories_patches_insert)
          "update" ->
            all_categories_patches_update = Category.fetch_all_categories_patches_update
            render(conn, "index_patches_update.json", categories_patches: all_categories_patches_update)
          "delete" ->
            all_categories_patches_delete = Category.fetch_all_categories_patches_delete
            render(conn, "index_patches_delete.json", categories_patches: all_categories_patches_delete)
          _ ->
            conn
            |> put_status(404)
            |> render(PhpInternals.ErrorView, "error.json", error: "Unknown patches type specified")
        end
    end
  end

  def index(conn, %{"status" => "deleted"}) do
    cond do
      conn.user.privilege_level == 0 ->
        conn
        |> put_status(401)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
      conn.user.privilege_level in [1, 2] ->
        conn
        |> put_status(403)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
      conn.user.privilege_level == 3 ->
        all_deleted_categories = Category.fetch_all_categories_deleted
        render(conn, "index_normal.json", categories: all_deleted_categories)
    end
  end

  def index(conn, params) do
    with {:ok, view_type} <- Category.valid_view_type?(params["view"]),
         {:ok, order_by} <- Category.valid_order_by?(params["order_by"]),
         {:ok, ordering} <- Utilities.valid_ordering?(params["ordering"]),
         {:ok, offset} <- Utilities.valid_offset?(params["offset"]),
         {:ok, limit} <- Utilities.valid_limit?(params["limit"]) do
      render(conn, "index_#{view_type}.json", categories: Category.fetch_all_categories(view_type, order_by, ordering, offset, limit))
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(conn, %{"category_name" => category_url, "patches" => scope} = params) do
    cond do
      conn.user.privilege_level == 0 ->
        conn
        |> put_status(401)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
      conn.user.privilege_level == 1 ->
        conn
        |> put_status(403)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
      conn.user.privilege_level in [2, 3] ->
        if scope == "insert" do
          category_patch_insert = Category.fetch_category_patch_insert(category_url)

          if category_patch_insert == [] do
            conn
            |> put_status(404)
            |> render(PhpInternals.ErrorView, "error.json", error: "Category insert not found")
          else
            render(conn, "show_insert.json", category: List.first category_patch_insert)
          end
        else
          with {:ok, %{"category" => _category}} <- Category.category_exists?(category_url) do
            case scope do
              "all" ->
                render(conn, "index_patches_changes.json", category: List.first(Category.fetch_category_patches(category_url)))
              "update" ->
                if Map.has_key?(params, "patch_id") do
                  category_patch_update = Category.fetch_category_patch_update(category_url, params["patch_id"])

                  if category_patch_update == [] do
                    conn
                    |> put_status(404)
                    |> render(PhpInternals.ErrorView, "error.json", error: "Category update patch not found")
                  else
                    render(conn, "show_update.json", category: List.first category_patch_update)
                  end
                else
                  category_patches_update = Category.fetch_category_patches_update(category_url)

                  if category_patches_update == [] do
                    conn
                    |> put_status(404)
                    |> render(PhpInternals.ErrorView, "error.json", error: "Category update patches not found")
                  else
                    render(conn, "show_updates.json", category: List.first category_patches_update)
                  end
                end
              "delete" ->
                category_patch_delete = Category.fetch_category_patch_delete(category_url)

                if category_patch_delete == [] do
                  conn
                  |> put_status(404)
                  |> render(PhpInternals.ErrorView, "error.json", error: "Category delete patch not found")
                else
                  render(conn, "show_delete.json", category: List.first category_patch_delete)
                end
            end
          else
            {:error, status_code, error} ->
              conn
              |> put_status(status_code)
              |> render(PhpInternals.ErrorView, "error.json", error: error)
          end
        end
    end
  end

  def show(conn, %{"category_name" => category_name, "view" => "full"}) do
    category = Category.fetch_category_full(category_name)

    if category == []do
      conn
      |> put_status(404)
      |> render(PhpInternals.ErrorView, "error.json", error: "Category not found")
    else
      render(conn, "show_full.json", category: List.first category)
    end
  end

  def show(conn, %{"category_name" => category_name, "view" => "overview"}) do
    category = Category.fetch_category_overview(category_name)

    if category == [] do
      conn
      |> put_status(404)
      |> render(PhpInternals.ErrorView, "error.json", error: "Category not found")
    else
      render(conn, "show_overview.json", category: List.first category)
    end
  end

  def show(conn, %{"category_name" => category_name}) do
    category = Category.fetch_category(category_name)

    if category == [] do
      conn
      |> put_status(404)
      |> render(PhpInternals.ErrorView, "error.json", error: "Category not found")
    else
      render(conn, "show.json", category: List.first category)
    end
  end

  def insert(conn, params) do
    if conn.user.privilege_level > 0 do
      review =
        cond do
          conn.user.privilege_level === 1 -> 1
          Map.has_key?(params, "review") -> String.to_integer(params["review"])
          true -> 0
        end
      params = Map.put(params, "review", review)

      insert_category(conn, params)
    else
      conn
      |> put_status(401)
      |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
    end
  end

  def update(conn, %{"apply_patch" => action, "category_name" => category_name}) do
    cond do
      conn.user.privilege_level == 0 ->
        conn
        |> put_status(401)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
      conn.user.privilege_level == 1 ->
        conn
        |> put_status(403)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
      conn.user.privilege_level in [2, 3] ->
        category = Category.accept_category_patch(category_name, action)

        case category do
          {:error, status_code, message} ->
            conn
            |> put_status(status_code)
            |> render(PhpInternals.ErrorView, "error.json", error: message)
          {:ok, status_code} when is_integer(status_code) ->
            conn
            |> send_resp(status_code, "")
          {:ok, category} ->
            render(conn, "show.json", category: category)
        end
    end
  end

  def update(conn, %{"discard_patch" => action, "category_name" => category_name}) do
    cond do
      conn.user.privilege_level == 0 ->
        conn
        |> put_status(401)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
      conn.user.privilege_level == 1 ->
        conn
        |> put_status(403)
        |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
      conn.user.privilege_level in [2, 3] ->
        return = Category.discard_category_patch(category_name, action)

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
  end

  def update(conn, params) do
    if conn.user.privilege_level > 0 do
      review =
        cond do
          conn.user.privilege_level === 1 -> 1
          Map.has_key?(params, "review") -> String.to_integer(params["review"])
          true -> 0
        end
      params = Map.put(params, "review", review)

      update_category(conn, params)
    else
      conn
      |> put_status(401)
      |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
    end
  end

  def delete(conn, params) do
    if conn.user.privilege_level > 0 do
      review =
        cond do
          conn.user.privilege_level === 1 -> 1
          Map.has_key?(params, "review") -> String.to_integer(params["review"])
          true -> 0
        end
      params = Map.put(params, "review", review)

      delete_category(conn, params)
    else
      conn
      |> put_status(401)
      |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
    end
  end

  def insert_category(conn, %{"category" => category, "review" => review}) do
    with {:ok} <- Category.contains_required_fields?(category),
         {:ok} <- Category.contains_only_expected_fields?(category) do
      url_name = Utilities.make_url_friendly_name(category["name"])
      category =
        category
        |> Map.put("url_name", url_name)
        |> Category.insert_category(review)

      status_code = if review == 0, do: 201, else: 202

      conn
      |> put_status(status_code)
      |> render("show.json", category: category)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def update_category(conn, %{"category" => %{} = category, "category_name" => old_url_name, "review" => review} = params) do
    with {:ok} <- Category.contains_required_fields?(category),
         {:ok} <- Category.contains_only_expected_fields?(category),
         {:ok, %{"category" => old_category}} <- Category.category_exists?(old_url_name) do
      new_url_name = Utilities.make_url_friendly_name(category["name"])

      category = Map.merge(category, %{"new_url" => new_url_name, "old_url" => old_url_name})

      category =
        if Map.has_key?(params, "references_patch") do
          if conn.user.privilege_level == 1 do
            {:error, 403, "Unauthorised action"}
          else
            Category.update_category(category, old_category, review, params["references_patch"])
          end
        else
          Category.update_category(category, old_category, review)
        end

      case category do
        {:error, status_code, error} ->
          conn
          |> put_status(status_code)
          |> render(PhpInternals.ErrorView, "error.json", error: error)
        {:ok, status_code, category} ->
          conn
          |> put_status(status_code)
          |> render("show.json", category: category)
      end
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def update_category(conn, _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Incomplete request data")
  end

  def delete_category(conn, %{"category_name" => url_name, "review" => review}) do
    with {:ok, _category} <- Category.category_exists?(url_name),
         {:ok} <- Category.contains_no_symbols?(url_name) do
      Category.soft_delete_category(url_name, review)

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
