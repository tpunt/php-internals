defmodule PhpInternals.Api.Articles.ArticleView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Articles.ArticleView
  alias PhpInternals.Api.Users.UserView

  def render("index_full.json", %{articles: articles}) do
    %{articles: render_many(articles, ArticleView, "show_full.json")}
  end

  def render("index_overview.json", %{articles: articles}) do
    %{articles: render_many(articles, ArticleView, "show_overview.json")}
  end

  def render("show_full.json", %{article: article}) do
    %{article: render_one(article, ArticleView, "article_full.json")}
  end

  def render("show_overview.json", %{article: article}) do
    %{article: render_one(article, ArticleView, "article_overview.json")}
  end

  def render("article_full.json", %{article: %{"article" => article}}) do
    %{title: article["title"], url: article["url"], excerpt: article["excerpt"], body: article["body"], date: article["date"]}
    |> Map.merge(%{author: UserView.render("user.json", %{user: %{"user" => article["user"]}})})
    |> Map.merge(CategoryView.render("index_overview.json", %{categories: article["categories"]}))
  end

  def render("article_overview.json", %{article: %{"article" => article}}) do
    %{title: article["title"], url: article["url"], excerpt: article["excerpt"], date: article["date"]}
    |> Map.merge(%{author: UserView.render("user.json", %{user: %{"user" => article["user"]}})})
    |> Map.merge(CategoryView.render("index_overview.json", %{categories: article["categories"]}))
  end
end
