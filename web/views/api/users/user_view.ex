defmodule PhpInternals.Api.Users.UserView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Users.UserView
  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Symbols.SymbolView

  def render("index.json", %{users: users}) do
    %{users: render_many(users, UserView, "show_overview.json")}
  end

  def render("show_overview.json", %{user: user}) do
    %{user: render_one(user, UserView, "user_overview.json")}
  end

  def render("show_full.json", %{user: user}) do
    %{user: render_one(user, UserView, "user_full.json")}
  end

  def render("show_contributions.json", %{user: user, contributions: contributions}) do
    contributions =
      contributions
      |> Enum.map(fn %{"contribution" => %{"filter" => filter, "towards" => towards} = data} ->
          if filter === "category" do
            Map.put(data, "towards", CategoryView.render("show_overview.json", %{category: towards}))
          else
            Map.put(data, "towards", SymbolView.render("show_overview.json", %{symbol: towards}))
          end
        end)

    Map.merge(render("show_overview.json", user: user), %{"contributions" => contributions})
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
