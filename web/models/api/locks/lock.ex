defmodule PhpInternals.Api.Locks.Lock do
  use PhpInternals.Web, :model
  use GenServer

  alias PhpInternals.Stats.Counter, as: Redix

  @doc """
  Details:
  Lock TTLs are 10 minutes
  Max locks per privilege level (PL): PL 1 = 10 locks, PL 2 = 30 locks, PL 3 = 100
  Updates and deletes must have a lock acquired (or they will be rejected)
  Lock types:
     - "acquire" acquires a lock. It fails if the lock is already acquired or a user is holding their max locks
     - "reacquire" extends the lock lifetime to 10 minutes again. It fails if the lock was initially acquire > 20 minutes ago
     - "release" releases a lock. It fails if the lock is not acquired or if the user does not own the lock
     - "force_release" forces the release of any lock (admins only). It fails if the lock is not acquired
  """

  @max_lock_hold_time 1200 # seconds = 20 minutes
  @default_lock_expiration_time 600 # seconds = 10 minutes
  @valid_lock_types ["acquire", "release", "reacquire", "force_release"]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def valid_lock_type?(lock_type, privilege_level) do
    if lock_type in @valid_lock_types do
      if lock_type === "force_release" and privilege_level !== 3 do
        {:error, 400, "The force_release lock type is for admins only"}
      else
        {:ok}
      end
    else
      {:error, 400, "Invalid lock type"}
    end
  end

  def attempt(lock_type, revision_id, username, privilege_level) do
    GenServer.call(__MODULE__, {:attempt, lock_type, revision_id, username, privilege_level})
  end

  # for the optional references_patch query string parameter
  def has_lock?(nil, _username), do: {:ok}

  def has_lock?(revision_id, username) do
    case Redix.exec(["hget", "locks:#{revision_id}", "username"]) do
      {:ok, ^username} -> {:ok}
      {:ok, _result} -> {:error, 400, "You are not holding this resource's lock"}
    end
  end

  defp max_lock_count(privilege_level) do
    case privilege_level do
      1 -> 10
      2 -> 30
      3 -> 100
    end
  end

  defp fetch_lock_count(username, cursor) do
    {:ok, [cursor, locks]} = Redix.exec(["scan", cursor])

    counter =
      Enum.reduce(locks, 0, fn lock, counter ->
        if String.starts_with?(lock, "locks") do
          case Redix.exec(["hget", lock, "username"]) do
            {:ok, ^username} -> counter + 1
            _ -> counter
          end
        else
          counter
        end
      end)

    if cursor === "0" do
      counter
    else
      counter + fetch_lock_count(username, cursor)
    end
  end

  defp acquire_lock(revision_id, username, privilege_level) do
    if fetch_lock_count(username, "0") >= max_lock_count(privilege_level) do
      {:error, 400, "You have exceeded your maximum lock count of #{max_lock_count(privilege_level)}"}
    else
      Redix.execp([
        ["hset", "locks:#{revision_id}", "username", username],
        ["hset", "locks:#{revision_id}", "tol", :os.system_time(:seconds)],
        ["expire", "locks:#{revision_id}", @default_lock_expiration_time]
      ])
      {:ok}
    end
  end

  defp delete_lock(revision_id) do
    Redix.exec(["del", "locks:#{revision_id}"])
    {:ok}
  end

  def handle_call({:attempt, lock_type, revision_id, username, privilege_level}, _from, state) do
    result =
      case lock_type do
        "acquire" ->
          case Redix.exec(["hget", "locks:#{revision_id}", "username"]) do
            {:ok, nil} -> acquire_lock(revision_id, username, privilege_level)
            {:ok, ^username} -> {:error, 400, "You are already holding this lock"}
            {:ok, _result} -> {:error, 400, "This lock is already being held by someone else"}
          end
        "release" ->
          case Redix.exec(["hget", "locks:#{revision_id}", "username"]) do
            {:ok, nil} -> {:error, 400, "This lock is not being held by anyone"}
            {:ok, ^username} -> delete_lock(revision_id)
            {:ok, _result} -> {:error, 400, "You cannot release this lock because you are not the holder of it"}
          end
        "reacquire" ->
          case Redix.exec(["hget", "locks:#{revision_id}", "username"]) do
            {:ok, nil} -> acquire_lock(revision_id, username, privilege_level)
            {:ok, ^username} ->
              case Redix.exec(["hget", "locks:#{revision_id}", "tol"]) do
                {:ok, nil} -> acquire_lock(revision_id, username, privilege_level)
                {:ok, result} ->
                  cond do
                    String.to_integer(result) + @max_lock_hold_time > :os.system_time(:seconds) ->
                      case Redix.exec(["expire", "locks:#{revision_id}", @default_lock_expiration_time]) do
                        {:ok, 0} -> acquire_lock(revision_id, username, privilege_level)
                        {:ok, 1} -> {:ok}
                      end
                    true -> {:error, 400, "You cannot reacquire this lock because you have held it for too long"}
                  end
              end
            {:ok, _result} -> {:error, 400, "You cannot reacquire this lock because you are not the holder of it"}
          end
        "force_release" ->
          case Redix.exec(["exists", "locks:#{revision_id}"]) do
            {:ok, 0} -> {:error, 400, "This lock is not being held by anyone"}
            {:ok, 1} -> delete_lock(revision_id)
          end
      end

    {:reply, result, state}
  end

  def init(args) do
    {:ok, args}
  end
end
