defmodule PhpInternals.Cache.ResultCache do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [{:ets_table_name, :result_cache}, {:log_limit, 1_000_000}], opts)
  end

  def fetch(url, callback) do
    case get(url) do
      {:not_found} -> set(url, callback.())
      {:found, result} -> result
    end
  end

  def fetch(url, invalidate_cache_after, callback) do
    case get_timed(url, invalidate_cache_after) do
      {:not_found} -> set(url, callback.())
      {:found, result} -> result
    end
  end

  def invalidate(url) do
    GenServer.call(__MODULE__, {:delete, url})
  end

  def flush(url) do
    GenServer.call(__MODULE__, {:delete_all, url})
  end

  def get(url) do
    case GenServer.call(__MODULE__, {:get, url}) do
      [] -> {:not_found}
      [{_url, {result, _time}}] ->
        {:found, result}
    end
  end

  def get_timed(url, invalidate_cache_after) do
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

  def set(url, result) do
    GenServer.call(__MODULE__, {:set, url, result})
  end

  def group(key, url) do
    GenServer.call(__MODULE__, {:group, key, url})
  end

  def handle_call({:get, url}, _from, state) do
    {:reply, :ets.lookup(state.ets_table_name, url), state}
  end

  def handle_call({:set, url, result}, _from, state) do
    true = :ets.insert(state.ets_table_name, {url, {result, :os.system_time(:seconds)}})
    {:reply, result, state}
  end

  def handle_call({:delete, url}, _from, state) do
    :ets.delete(state.ets_table_name, url)
    {:reply, nil, state}
  end

  def handle_call({:delete_all, url}, _from, state) do
    for key <- state.groups[url] do
      :ets.delete(state.ets_table_name, key)
    end

    {:reply, nil, Kernel.put_in(state, [:groups, url], [])}
  end

  def handle_call({:group, key, url}, _from, state) do
    {:reply, nil, Kernel.put_in(state, [:groups, key], state.groups[key] ++ [url])}
  end

  def init(args) do
    [{:ets_table_name, ets_table_name}, {:log_limit, log_limit}] = args

    :ets.new(ets_table_name, [:named_table, :set, :private])
    groups = %{"articles" => [], "symbols" => [], "categories" => [], "users" => []}

    {:ok, %{log_limit: log_limit, ets_table_name: ets_table_name, groups: groups}}
  end
end
