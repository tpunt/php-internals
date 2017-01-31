defmodule PhpInternals.Endpoint do
  use Phoenix.Endpoint, otp_app: :php_internals

  if code_reloading? do
  plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Plug.MethodOverride
  plug Plug.Head

  plug Corsica,
    origins: "*",
    allow_headers: [
      "accept",
      "accept-encoding",
      "accept-language",
      "cache-control",
      "connection",
      "host",
      "origin",
      "referer",
      "user-agent",
      "content-type",
      "authorization"
    ],
    log: [invalid: :error, rejected: :error, accepted: :debug]

  plug PhpInternals.Router
end
