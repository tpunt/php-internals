defmodule PhpInternals.Api.Users.UserView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Users.UserView

  def render("index.json", %{users: users}) do
    %{users: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{user: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: %{"user" => user}}) do
    %{username: user["username"], name: user["name"], privilege_level: user["privilege_level"]}
  end
end
