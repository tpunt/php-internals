defmodule PhpInternals.Api.Settings.SettingController do
  use PhpInternals.Web, :controller

  alias PhpInternals.Api.Settings.Setting
  alias PhpInternals.Api.Settings.SettingView

  def index(%{user: %{privilege_level: 3}} = conn, _params) do
    settings = Phoenix.View.render_to_string(SettingView, "index.json", settings: Setting.get_all)

    conn
    |> send_resp(200, settings)
  end

  def index(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def index(%{user: %{privilege_level: _pl}} = conn, _params) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def show(%{user: %{privilege_level: 3}} = conn, %{"setting_name" => setting_name} = _params) do
    with {:ok} <- Setting.valid_setting?(setting_name) do
      setting = %{setting_name => Setting.get(setting_name)}
      setting = Phoenix.View.render_to_string(SettingView, "show.json", setting: setting)

      conn
      |> send_resp(200, setting)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def show(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def show(%{user: %{privilege_level: _pl}} = conn, _params) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end

  def update(%{user: %{privilege_level: 3}} = conn, %{"setting_name" => setting_name, "value" => value} = _params) do
    with {:ok} <- Setting.valid_setting?(setting_name),
         {:ok} <- Setting.validate_field(setting_name, value) do
      setting = %{setting_name => Setting.set(setting_name, value)}
      setting = Phoenix.View.render_to_string(SettingView, "show.json", setting: setting)

      conn
      |> send_resp(200, setting)
    else
      {:error, status_code, error} ->
        conn
        |> put_status(status_code)
        |> render(PhpInternals.ErrorView, "error.json", error: error)
    end
  end

  def update(%{user: %{privilege_level: 3}} = conn, %{"setting_name" => _setting_name} = _params) do
    conn
    |> put_status(400)
    |> render(PhpInternals.ErrorView, "error.json", error: "Invalid input format")
  end

  def update(%{user: %{privilege_level: 0}} = conn, _params) do
    conn
    |> put_status(401)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthenticated access attempt")
  end

  def update(%{user: %{privilege_level: _pl}} = conn, _params) do
    conn
    |> put_status(403)
    |> render(PhpInternals.ErrorView, "error.json", error: "Unauthorised access attempt")
  end
end
