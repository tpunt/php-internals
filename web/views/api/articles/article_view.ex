defmodule PhpInternals.Api.Articles.ArticleView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Articles.ArticleView
  alias PhpInternals.Api.Users.UserView
  alias PhpInternals.Api.UtilitiesView

  def render("index.json", %{articles: %{"articles" => articles, "meta" => meta}}) do
    %{articles: render_many(articles, ArticleView, "show_overview.json"),
      meta: UtilitiesView.render("meta.json", meta)}
  end

  # viewing article series is not paginated currently
  def render("index.json", %{articles: articles}) do
    %{articles: render_many(articles, ArticleView, "show_overview.json")}
  end

  def render("show_full.json", %{article: article}) do
    %{article: render_one(article, ArticleView, "article_full.json")}
  end

  def render("show_overview.json", %{article: article}) do
    %{article: render_one(article, ArticleView, "article_overview.json")}
  end

  def render("article_full.json", %{article: %{"article" => article}}) do
    %{title: article["title"], url: article["url"], excerpt: article["excerpt"],
      body: article["body"], date: article["date"], series_name: article["series_name"],
      series_url: article["series_url"]}
    |> Map.merge(%{author: UserView.render("user_overview.json", %{user: %{"user" => article["user"]}})})
    |> Map.merge(CategoryView.render("index_overview.json", %{categories: article["categories"]}))
  end

  def render("article_overview.json", %{article: %{"article" => article}}) do
    %{title: article["title"], url: article["url"], excerpt: article["excerpt"],
      date: article["date"], series_name: article["series_name"], series_url: article["series_url"]}
    |> Map.merge(%{author: UserView.render("user_overview.json", %{user: %{"user" => article["user"]}})})
    |> Map.merge(CategoryView.render("index_overview.json", %{categories: article["categories"]}))
  end

  # Used in users view for showing article contributions
  def render("show_brief_overview.json", %{article: article}) do
    %{article:
      %{title: article["title"], url: article["url"], date: article["date"],
        series_name: article["series_name"], series_url: article["series_url"]}}
  end
end
