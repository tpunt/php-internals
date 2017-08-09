defmodule PhpInternals.Api.Contributions.ContributionView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Contributions.ContributionView
  alias PhpInternals.Api.Users.UserView
  alias PhpInternals.Api.UtilitiesView

  def render("index.json", %{contributions: contributions}) do
    %{
      contributions: render_many(contributions["contributors"], ContributionView, "show.json"),
      meta: UtilitiesView.render("meta.json", contributions["meta"]),
      total_contributions: contributions["total_contributions"]
    }
  end

  def render("show.json", %{contribution: contributor}) do
    %{contribution: render_one(contributor, ContributionView, "contribution.json")}
  end

  # def render("show.json", a), do: IO.inspect a

  def render("contribution.json", %{contribution: %{"contribution_count" => contribution_count, "user" => user}}) do
    %{
      user: UserView.render("user_overview.json", %{user: %{"user" => user}}),
      contribution_count: contribution_count
    }
  end
end
