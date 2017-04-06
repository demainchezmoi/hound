defmodule Hound.SessionServer do
  @moduledoc false

  use GenServer
  @name __MODULE__


  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end


  def start_session_for_pid(pid, opts) do
    GenServer.call(@name, {:start_session, pid, opts}, 60000)
  end


  def current_session_id(pid) do
    GenServer.call(@name, {:current_session, pid}, 60000)
  end


  def change_current_session_for_pid(pid, session_id) do
    GenServer.call(@name, {:change_session, pid, session_id}, 60000)
  end


  def destroy_session_for_pid(pid) do
    GenServer.call(@name, {:destroy_session, pid}, 60000)
  end


  ## Callbacks


  def init(state) do
    :ets.new(@name, [:set, :named_table, :protected, read_concurrency: true])
    {:ok, state}
  end


  def handle_call({:start_session, pid, opts}, _from, state) do
    {:ok, driver_info} =
      Hound.driver_info

    {:ok, session_id} =
      Hound.Session.create_session(driver_info[:browser], opts)

    :ets.insert @name, {pid, session_id}

    {:reply, session_id, state}
  end


  def handle_call({:current_session, pid}, _from, state) do
    reply =
      case :ets.lookup(@name, pid) do
        [{^pid, session_id}] -> session_id
        [] -> nil
      end
    {:reply, reply, state}
  end


  def handle_call({:change_session, pid, session_id}, _from, state) do
    if (!Enum.any?(Hound.Session.active_sessions(), fn(session) -> session["id"] == session_id end)) do
      raise "Error: Session id does not exist"
    end

    :ets.insert @name, {pid, session_id}

    {:reply, session_id, state}
  end


  def handle_call({:destroy_session, pid}, _from, state) do

    session_id =
      case :ets.lookup(@name, pid) do
        [{^pid, session_id}] -> session_id
        _ -> raise "Error: Session does not exist for pid"
      end

    Hound.Session.destroy_session(session_id)

    :ets.delete @name, pid

    {:reply, :ok, state}
  end
end
