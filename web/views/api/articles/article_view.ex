defmodule PhpInternals.Api.Articles.ArticleView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Docs.CategoryView
  alias PhpInternals.Api.Articles.ArticleView
  alias PhpInternals.Api.Users.UserView

  def render("index.json", %{articles: articles}) do
    %{articles: render_many(articles, ArticleView, "show.json")}
  end

  def render("show.json", %{article: article}) do
    %{article: render_one(article, ArticleView, "article.json")}
  end

  def render("article.json", %{article: %{"article" => article}}) do
    %{title: article["title"], url: article["url"], body: article["body"]}
    |> Map.merge(UserView.render("show.json", %{user: %{"user" => article["user"]}}))
    |> Map.merge(CategoryView.render("index_overview.json", %{categories: article["categories"]}))
  end
end
