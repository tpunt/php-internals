defmodule PhpInternals.Api.Contributions.ContributionView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Contributions.ContributionView
  alias PhpInternals.Api.Articles.ArticleView
  alias PhpInternals.Api.Users.UserView
  alias PhpInternals.Api.Categories.CategoryView
  alias PhpInternals.Api.Symbols.SymbolView
  alias PhpInternals.Api.UtilitiesView

  def render("index_overview.json", %{contributions: contributions}) do
    %{
      contributions: render_many(contributions["contributors"], ContributionView, "show_overview.json"),
      meta: UtilitiesView.render("meta.json", contributions["meta"]),
      total_contributions: contributions["total_contributions"]
    }
  end

  def render("index_overview_for_user.json", %{contributions: contributions}) do
    %{contribution_history: render_many(contributions, ContributionView, "show_overview_for_user.json")}
  end

  def render("index_normal.json", %{contributions: %{"contributions" => contributions, "meta" => meta}}) do
    %{
      contributions: render_many(contributions, ContributionView, "show_normal.json"),
      meta: UtilitiesView.render("meta.json", meta)
    }
  end

  def render("index_normal_for_user.json", %{contributions: %{"contributions" => contributions, "meta" => meta}}) do
    %{
      contributions: render_many(contributions, ContributionView, "show_normal_for_user.json"),
      meta: UtilitiesView.render("meta.json", meta)
    }
  end

  def render("show_overview.json", %{contribution: contributor}) do
    %{contribution: render_one(contributor, ContributionView, "contribution_overview.json")}
  end

  def render("show_overview_for_user.json", %{contribution: contributor}) do
    %{day: render_one(contributor, ContributionView, "contribution_overview_for_user.json")}
  end

  def render("show_normal.json", %{contribution: contribution}) do
    %{contribution: render_one(contribution, ContributionView, "contribution_normal.json")}
  end

  def render("show_normal_for_user.json", %{contribution: contributor}) do
    %{contribution: render_one(contributor, ContributionView, "contribution_normal_for_user.json")}
  end

  def render("contribution_overview.json", %{contribution: %{"contribution_count" => contribution_count, "author" => author}}) do
    %{
      author: UserView.render("user_overview.json", %{user: %{"user" => author}}),
      contribution_count: contribution_count
    }
  end

  def render("contribution_overview_for_user.json", %{contribution: %{"day" => contribution}}) do
    %{
      date: render_date(contribution["date"]),
      contribution_count: contribution["contribution_count"]
    }
  end

  def render("contribution_normal.json", %{contribution: contribution}) do
    contribution = Map.put(contribution, "date", render_date(contribution["date"]))
    contribution = Map.put(contribution, "author", UserView.render("user_overview.json", %{user: %{"user" => contribution["author"]}}))

    case contribution["filter"] do
      "category" ->
        Map.put(contribution, "towards", CategoryView.render("show_overview.json", %{category: contribution["towards"]}))
      "article" ->
        Map.put(contribution, "towards", ArticleView.render("show_brief_overview.json", %{article: contribution["towards"]}))
      "symbol" ->
        Map.put(contribution, "towards", SymbolView.render("show_overview.json", %{symbol: contribution["towards"]}))
    end
  end

  def render("contribution_normal_for_user.json", %{contribution: contribution}) do
    contribution = Map.put(contribution, "date", render_date(contribution["date"]))

    case contribution["filter"] do
      "category" ->
        Map.put(contribution, "towards", CategoryView.render("show_overview_without_categories.json", %{category: contribution["towards"]}))
      "article" ->
        Map.put(contribution, "towards", ArticleView.render("show_brief_overview.json", %{article: contribution["towards"]}))
      "symbol" ->
        Map.put(contribution, "towards", SymbolView.render("show_overview.json", %{symbol: contribution["towards"]}))
    end
  end

  defp render_date(date) do
    <<year::binary-size(4), month::binary-size(2), day::binary>> = Integer.to_string(date)
    "#{year}-#{month}-#{day}"
  end
end
