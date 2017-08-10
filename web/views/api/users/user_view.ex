defmodule PhpInternals.Api.Users.UserView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Articles.ArticleView
  alias PhpInternals.Api.Users.UserView
  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Symbols.SymbolView
  alias PhpInternals.Api.UtilitiesView

  def render("index.json", %{users: %{"users" => users, "meta" => meta}}) do
    %{users: render_many(users, UserView, "show_overview.json"),
      meta: UtilitiesView.render("meta.json", meta)}
  end

  def render("show_overview.json", %{user: user}) do
    %{user: render_one(user, UserView, "user_overview.json")}
  end

  def render("show_full.json", %{user: user}) do
    %{user: render_one(user, UserView, "user_full.json")}
  end

  def render("user_overview.json", %{user: %{"user" => user}}) do
    %{
      username: user["username"],
      name: user["name"],
      privilege_level: user["privilege_level"],
      avatar_url: user["avatar_url"]
    }
  end

  def render("user_full.json", %{user: %{"user" => user}}) do
    %{
      username: user["username"],
      name: user["name"],
      privilege_level: user["privilege_level"],
      avatar_url: user["avatar_url"],
      blog_url: user["blog_url"],
      email: user["email"],
      bio: user["bio"],
      location: user["location"],
      github_url: user["github_url"]
    }
  end
end
