defmodule PhpInternals.Api.Users.UserView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Users.UserView
  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Symbols.SymbolView

  def render("index.json", %{users: users}) do
    %{users: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{user: render_one(user, UserView, "user.json")}
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

    Map.merge(render("show.json", user: user), %{"contributions" => contributions})
  end

  def render("user.json", %{user: %{"user" => user}}) do
    %{username: user["username"], name: user["name"], privilege_level: user["privilege_level"]}
  end
end
