defmodule PhpInternals.Router do
  use PhpInternals.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug PhpInternals.Auth.ConnAuth
  end

  scope "/api", PhpInternals.Api, as: :api do
    pipe_through :api

    scope "/symbols", Symbols do
      get "/:symbol_id", SymbolController, :show
      patch "/:symbol_id", SymbolController, :update
      delete "/:symbol_id", SymbolController, :delete
      get "/:symbol_id/revisions/:revision_id", SymbolController, :show_revision
      get "/:symbol_id/revisions", SymbolController, :show_revisions
      get "/:symbol_id/updates/:update_id", SymbolController, :show_update
      get "/:symbol_id/updates", SymbolController, :show_updates
      get "/", SymbolController, :index
      post "/", SymbolController, :create
    end

    scope "/categories", Categories do
      get "/:category_name", CategoryController, :show
      patch "/:category_name", CategoryController, :update
      delete "/:category_name", CategoryController, :delete
      get "/:category_name/revisions/:revision_id", CategoryController, :show_revision
      get "/:category_name/revisions", CategoryController, :show_revisions
      get "/:category_name/updates/:update_id", CategoryController, :show_update
      get "/:category_name/updates", CategoryController, :show_updates
      get "/", CategoryController, :index
      post "/", CategoryController, :create
    end

    scope "/articles", Articles do
      get "/:series_name/:article_name", ArticleController, :show
      patch "/:series_name/:article_name", ArticleController, :update
      delete "/:series_name/:article_name", ArticleController, :delete
      get "/:article_name", ArticleController, :show
      patch "/:article_name", ArticleController, :update
      delete "/:article_name", ArticleController, :delete
      get "/", ArticleController, :index
      post "/", ArticleController, :create
    end

    scope "/users", Users do
      get "/:username", UserController, :show
      patch "/:username", UserController, :update
      get "/", UserController, :index
    end

    scope "/user", Users do
      get "/", UserController, :self
    end

    scope "/auth", Auth do
      get "/:provider", AuthController, :index
      get "/:provider/callback", AuthController, :callback
      delete "/logout", AuthController, :logout
    end

    scope "/contributions", Contributions do
      get "/", ContributionController, :index
    end
  end

  scope "/", PhpInternals.Site, as: :site do
    get "/", HomeController, :index
  end
end
