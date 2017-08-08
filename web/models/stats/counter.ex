defmodule PhpInternals.Stats.Counter do
  alias PhpInternals.Stats.Supervisor

  def exec(command) do
    Redix.command(:"redix_#{:rand.uniform(Supervisor.pool_size)}", command)
  end
end
