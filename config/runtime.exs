import Config

get_atom = fn(key, default) ->
  if value = System.get_env(key) do
    String.to_atom(value)
  else
    default
  end
end

config :ecto_mnesia,
  host: get_atom.("MNESIA_HOST", Kernel.node()),
  storage_type: get_atom.("MNESIA_STORAGE_TYPE", :disc_copies)
