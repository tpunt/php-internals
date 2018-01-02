defmodule PhpInternals.Api.Settings.Setting do
  use PhpInternals.Web, :model
  use GenServer

  @default_cache_expiration_time 0
  @valid_settings ["cache_expiration_time"]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{"cache_expiration_time" => @default_cache_expiration_time}, opts)
  end

  def valid_setting?(setting_name) do
    if setting_name in @valid_settings do
      {:ok}
    else
      {:error, 400, "Invalid setting name"}
    end
  end

  def validate_field("cache_expiration_time", value) do
    if is_integer(value) do
      {:ok}
    else
      {:error, 400, "Invalid setting value"}
    end
  end

  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  def get_all() do
    GenServer.call(__MODULE__, {:get_all})
    |> Enum.reduce([], fn {key, value}, acc ->
        [%{key => value} | acc]
      end)
  end

  def set(name, value) do
    GenServer.call(__MODULE__, {:set, name, value})
  end

  def handle_call({:get, name}, _from, state) do
    {:reply, state[name], state}
  end

  def handle_call({:get_all}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set, name, value}, _from, state) do
    query = """
      MATCH (settings:Settings)
      SET settings.#{name} = #{value}
    """

    Neo4j.query!(Neo4j.conn, query)

    {:reply, value, Map.put(state, name, value)}
  end

  def init(args) do
    spawn fn ->
      receive do
      after 2_000 -> ""
      end

      query = """
        MATCH (settings:Settings)
        RETURN settings.cache_expiration_time AS cache_expiration_time
      """

      result = List.first Neo4j.query!(Neo4j.conn, query)

      cache_expiration_time =
        if result === nil do
          Neo4j.query!(Neo4j.conn, "CREATE (:Settings {cache_expiration_time: 0})")
          0
        else
          %{"cache_expiration_time" => cache_expiration_time} = result
          cache_expiration_time
        end

      set("cache_expiration_time", cache_expiration_time)
    end

    {:ok, args}
  end
end
