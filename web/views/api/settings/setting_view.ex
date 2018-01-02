defmodule PhpInternals.Api.Settings.SettingView do
  use PhpInternals.Web, :view

  alias PhpInternals.Api.Settings.SettingView

  def render("index.json", %{settings: settings}) do
    %{settings: render_many(settings, SettingView, "show.json")}
  end

  def render("show.json", %{setting: setting}) do
    %{setting: setting}
  end
end
