defmodule PhpInternals.Stats.Supervisor do
  use Supervisor

  @redix_pool_size 10

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    redix_workers = for i <- 0..@redix_pool_size do
      worker(Redix, [[], [name: :"redix_#{i}"]], id: {Redix, i})
    end

    supervise(redix_workers, strategy: :one_for_one)
  end

  def pool_size, do: @redix_pool_size
end
