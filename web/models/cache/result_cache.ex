defmodule PhpInternals.Cache.ResultCache do
  use GenServer

  @default_cache_invalidation_time 5 # in seconds

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [{:ets_table_name, :result_cache}, {:log_limit, 1_000_000}], opts)
  end

  def fetch(url, invalidate_cache_after \\ @default_cache_invalidation_time, callback) do
    case get(url, invalidate_cache_after) do
      {:not_found} -> set(url, callback.())
      {:found, result} -> result
    end
  end

  defp get(url, invalidate_cache_after) do
    case GenServer.call(__MODULE__, {:get, url}) do
      [] -> {:not_found}
      [{_url, {result, time}}] ->
        if time + invalidate_cache_after >= :os.system_time(:seconds) do
          {:found, result}
        else
          {:not_found}
        end
    end
  end

  defp set(url, result) do
    GenServer.call(__MODULE__, {:set, url, result})
  end

  def handle_call({:get, url}, _from, state) do
    {:reply, :ets.lookup(state.ets_table_name, url), state}
  end

  def handle_call({:set, url, result}, _from, state) do
    true = :ets.insert(state.ets_table_name, {url, {result, :os.system_time(:seconds)}})
    {:reply, result, state}
  end

  def init(args) do
    [{:ets_table_name, ets_table_name}, {:log_limit, log_limit}] = args

    :ets.new(ets_table_name, [:named_table, :set, :private])

    {:ok, %{log_limit: log_limit, ets_table_name: ets_table_name}}
  end
end
