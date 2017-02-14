defmodule PhpInternals.Api.Categories.CategoryView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Symbols.SymbolView
  alias PhpInternals.Api.Articles.ArticleView

  def render("index_normal.json", %{categories: categories}) do
    %{categories: render_many(categories, CategoryView, "show.json")}
  end

  def render("index_overview.json", %{categories: categories}) do
    %{categories: render_many(categories, CategoryView, "show_overview.json")}
  end

  def render("index_patches_all.json", %{categories_patches: %{inserts: inserts, patches: patches}}) do
    %{categories_inserts: render_many(inserts, CategoryView, "show_insert.json"),
      categories_patches: render_many(patches, CategoryView, "index_patches_changes.json")}
  end

  def render("index_patches_changes.json", %{category: %{"category" => category, "patches" => patches}}) do
    updates = Enum.filter(patches, fn e -> e != %{} end)

    %{category: render_one(category, CategoryView, "category.json"),
      category_updates: render_many(updates, CategoryView, "show_updates2.json"),
      category_delete: Enum.member?(patches, %{})}
  end

  def render("show_updates2.json", %{category: category_update}) do
    render_one(category_update, CategoryView, "category_update.json")
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
    %{category_insert: %{category: render_one(category_insert, CategoryView, "category.json")}}
  end

  def render("show_insert.json", %{category: %{"category_delete" => category_delete}}) do
    %{category_insert: %{category: render_one(category_delete, CategoryView, "category.json")}}
  end

  def render("show_update.json", %{category: %{"category_update" => category_update}}) do
    %{category_update:
      %{category: render_one(category_update["category"], CategoryView, "category.json"),
        update: render_one(category_update["update"], CategoryView, "category_update.json")}}
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

  def render("show_full.json", %{category: category}) do
    %{category: render_one(category, CategoryView, "category_full.json")}
  end

  def render("show_patches.json", %{category_patches: category_patches}) do
    render_one(category_patches, CategoryView, "show_updates.json")
    |> Map.merge(render_one(category_patches, CategoryView, "show_delete.json"))
  end

  def render("category.json", %{category: category}) do
    %{name: category["name"],
      introduction: category["introduction"],
      url: category["url"],
      revision_id: category["revision_id"]}
  end

  def render("category_update.json", %{category: category_update}) do
    %{category_update:
      %{category:
        %{name: category_update["name"],
          introduction: category_update["introduction"],
          url: category_update["url"],
          revision_id: category_update["revision_id"],
          against_revision: category_update["against_revision"]}}}
  end

  def render("category_overview.json", %{category: %{"category" => category}}) do
    %{name: category["name"], url: category["url"]}
  end

  # used in symbols view
  def render("category_overview.json", %{category: category}) do
    %{name: category["name"], url: category["url"]}
  end

  def render("category_full.json", %{category: %{"category" => category}}) do
    %{name: category["name"],
      introduction: category["introduction"],
      url: category["url"],
      revision_id: category["revision_id"],
      symbols: render_many(category["symbols"], SymbolView, "show_overview.json"),
      articles: render_many(category["articles"], ArticleView, "show_overview.json")}
  end
end
