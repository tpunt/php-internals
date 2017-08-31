defmodule PhpInternals.Cache.ResultCache do
  use GenServer

  @invalidate_contributions_after 120

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [{:ets_table_name, :result_cache}, {:log_limit, 1_000_000}], opts)
  end

  def fetch(url, callback) do
    case get(url) do
      {:not_found} -> set(url, callback.())
      {:found, result} -> result
    end
  end

  def fetch_contributions(url, callback) do
    case get_contributions(url) do
      {:not_found} -> set(url, callback.())
      {:found, result} -> result
    end
  end

  def invalidate(url) do
    GenServer.call(__MODULE__, {:delete, url})
  end

  def invalidate_contributions() do
    GenServer.call(__MODULE__, {:invalidate_contributions})
  end

  def flush(group) do
    GenServer.call(__MODULE__, {:delete_all, group})
  end

  def get(url) do
    case GenServer.call(__MODULE__, {:get, url}) do
      [] -> {:not_found}
      [{_url, {result, _time}}] ->
        {:found, result}
    end
  end

  def get_contributions(url) do
    GenServer.call(__MODULE__, {:get_contributions, url})
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

  def handle_call({:get_contributions, url}, _from, state) do
    case :ets.lookup(state.ets_table_name, url) do
      [] -> {:reply, {:not_found}, state}
      [{_url, {result, time}}] ->
        if state.invalidate_contributions and :os.system_time(:seconds) >= time + @invalidate_contributions_after do
          # future optimisation: only flush contributions for the site, and that particular user (not every user)
          delete_all_from_group(state.groups["contributions"], state.ets_table_name)
          {:reply, {:not_found}, Kernel.put_in(state, [:invalidate_contributions], false)}
        else
          {:reply, {:found, result}, state}
        end
    end
  end

  def handle_call({:set, url, result}, _from, state) do
    true = :ets.insert(state.ets_table_name, {url, {result, :os.system_time(:seconds)}})
    {:reply, result, state}
  end

  def handle_call({:delete, url}, _from, state) do
    :ets.delete(state.ets_table_name, url)
    {:reply, nil, state}
  end

  def handle_call({:delete_all, group}, _from, state) do
    delete_all_from_group(state.groups[group], state.ets_table_name)
    {:reply, nil, Kernel.put_in(state, [:groups, group], [])}
  end

  def handle_call({:group, key, url}, _from, state) do
    {:reply, nil, Kernel.put_in(state, [:groups, key], state.groups[key] ++ [url])}
  end

  def handle_call({:invalidate_contributions}, _from, state) do
    {:reply, nil, Kernel.put_in(state, [:invalidate_contributions], true)}
  end

  def delete_all_from_group(group, table) do
    for key <- group do
      :ets.delete(table, key)
    end
  end

  def init(args) do
    [{:ets_table_name, ets_table_name}, {:log_limit, log_limit}] = args

    :ets.new(ets_table_name, [:named_table, :set, :private])

    {:ok, %{
      log_limit: log_limit,
      ets_table_name: ets_table_name,
      groups: %{"articles" => [], "symbols" => [], "categories" => [], "users" => [], "contributions" => []},
      invalidate_contributions: false}}
  end
end
