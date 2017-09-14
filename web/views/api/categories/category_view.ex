defmodule PhpInternals.Api.Categories.CategoryView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Users.UserView
  alias PhpInternals.Api.UtilitiesView

  def render("index_normal.json", %{categories: categories}) do
    %{categories: render_many(categories, CategoryView, "show.json")}
  end

  def render("index_overview.json", %{categories: %{"categories" => cats, "meta" => meta}}) do
    %{categories: render_many(cats, CategoryView, "show_overview.json"),
      meta: UtilitiesView.render("meta.json", meta)}
  end

  # used to render categories list for symbols/articles
  def render("index_overview.json", %{categories: categories}) do
    %{categories: render_many(categories, CategoryView, "show_overview.json")}
  end

  def render("index_patches_all.json", %{categories_patches: %{inserts: inserts, patches: patches}}) do
    %{categories_inserts: render_many(inserts, CategoryView, "show_insert.json"),
      categories_patches: render_many(patches, CategoryView, "index_patches_changes.json")}
  end

  def render("index_patches_changes.json", %{category: %{"patches" => patches}}) do
    %{category: render_one(patches["category"], CategoryView, "category.json"),
      category_updates: render_many(patches["updates"], CategoryView, "category_update.json"),
      category_delete: patches["delete"]}
  end

  def render("index_patches_insert.json", %{categories_patches: categories_patches}) do
    %{categories_inserts: render_many(categories_patches, CategoryView, "show_insert.json")}
  end

  def render("index_patches_update.json", %{categories_patches: categories_patches}) do
    %{categories_updates: render_many(categories_patches, CategoryView, "show_updates.json")}
  end

  def render("index_patches_delete.json", %{categories_patches: categories_patches}) do
    %{categories_deletes: render_many(categories_patches, CategoryView, "show_delete.json")}
  end

  def render("show.json", %{category: %{"category" => category}}) do
    %{category: render_one(category, CategoryView, "category.json")}
  end

  def render("show_insert.json", %{category: %{"category_insert" => category_insert}}) do
    %{
      category_insert: %{
        category: render_one(category_insert["category"], CategoryView, "category.json"),
        user: UserView.render("user_overview.json", %{user: %{"user" => category_insert["user"]}}),
        date: category_insert["date"]
      }
    }
  end

  def render("show_insert.json", %{category: %{"category_delete" => category_delete}}) do
    %{category_insert: %{category: render_one(category_delete, CategoryView, "category.json")}}
  end

  def render("show_update.json", %{category: %{"category_update" => category_update}}) do
    update = render_one(category_update["update"], CategoryView, "category_update.json")
    %{
      category_update: %{
        category: render_one(category_update["category"], CategoryView, "category.json"),
        update: %{
          category: update.category_update.category,
          user: update.category_update.user,
          date: update.category_update.date,
        }
      }
    }
  end

  def render("show_updates.json", %{category: %{"category_update" => category_update}}) do
    %{category_updates:
      %{category: render_one(category_update["category"], CategoryView, "category.json"),
        updates: render_many(category_update["updates"], CategoryView, "category_update.json")}}
  end

  def render("show_delete.json", %{category: %{"category_delete" => category_delete, "cd" => delete}}) do
    %{category_delete: %{delete: delete == %{},
        category: render_one(category_delete, CategoryView, "category.json")}}
  end

  def render("show_delete.json", %{category: %{"category_delete" => category_delete}}) do
    %{category_delete: %{delete: true,
      category: render_one(category_delete, CategoryView, "category.json")}}
  end

  def render("show_overview.json", %{category: category}) do
    %{category: render_one(category, CategoryView, "category_overview.json")}
  end

  def render("show_patches.json", %{category_patches: category_patches}) do
    render_one(category_patches, CategoryView, "show_updates.json")
    |> Map.merge(render_one(category_patches, CategoryView, "show_delete.json"))
  end

  def render("category.json", %{category: category}) do
    %{
      name: category["name"],
      introduction: category["introduction"],
      url: category["url"],
      revision_id: category["revision_id"]
    }
    |> Map.merge(render_linked_categories(category["subcategories"], category["supercategories"]))
  end

  def render("category_update.json", %{category: %{"update" => update, "user" => user, "date" => date}}) do
    category =
      %{against_revision: update["against_revision"]}
      |> Map.merge(render_one(update, CategoryView, "category.json"))

    %{
      category_update: %{
        category: category,
        user: UserView.render("user_overview.json", %{user: %{"user" => user}}),
        date: date
      }
    }
  end

  def render("category_overview.json", %{category: %{"category" => category}}) do
    %{name: category["name"], url: category["url"]}
    |> Map.merge(render_linked_categories(category["subcategories"], category["supercategories"]))
  end

  defp render_linked_categories(nil, nil), do: %{}
  defp render_linked_categories(subcategories, supercategories) do
    %{
      subcategories: render_many(subcategories, CategoryView, "show_overview.json"),
      supercategories: render_many(supercategories, CategoryView, "show_overview.json")
    }
  end
end
