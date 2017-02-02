defmodule PhpInternals.Router do
  use PhpInternals.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug PhpInternals.Auth.ConnAuth
  end

  scope "/api", PhpInternals.Api, as: :api do
    pipe_through :api

    scope "/docs", Docs do
      get "/categories", CategoryController, :index
      post "/categories", CategoryController, :insert
      get "/categories/:category_name", CategoryController, :show
      patch "/categories/:category_name", CategoryController, :update
      delete "/categories/:category_name", CategoryController, :delete
      get "/:symbol_name", SymbolController, :show
      patch "/:symbol_name", SymbolController, :update
      delete "/:symbol_name", SymbolController, :delete
      get "/", SymbolController, :index
      post "/", SymbolController, :create
    end

    scope "/articles", Articles do
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
  end

  scope "/", PhpInternals.Site, as: :site do
    get "/", HomeController, :index
  end
end
