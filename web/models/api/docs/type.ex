defmodule PhpInternals.Api.Docs.Type do
  use PhpInternals.Web, :model

  def fetch_all_types do
    query = "MATCH (symbol:Symbol) RETURN DISTINCT symbol.type AS type"

    Neo4j.query!(Neo4j.conn, query)
  end

  def fetch_symbol(symbol_name) do
    query = """
      MATCH (symbol:Symbol {name: {symbol_name}}) RETURN symbol
    """

    params = %{symbol_name: symbol_name}

    Neo4j.query!(Neo4j.conn, query, params)
  end
end
