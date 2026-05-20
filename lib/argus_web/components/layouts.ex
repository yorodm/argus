defmodule ArgusWeb.Layouts do
  @moduledoc false
  use ArgusWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :sidebar, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if @current_scope && @current_scope.user && @sidebar do %>
      <div class="min-h-screen bg-[#e8eaed] text-zinc-900">
        <header
          id="mobile-app-bar"
          class="sticky top-0 z-40 border-b border-zinc-200 bg-white/95 px-3 py-2.5 shadow-[0_1px_10px_rgba(15,23,42,0.08)] backdrop-blur lg:hidden"
        >
          <div class="flex items-center gap-3">
            <.link
              navigate={ArgusWeb.UserAuth.signed_in_path(@current_scope.user)}
              class="flex size-10 shrink-0 items-center justify-center rounded-[6px] border border-orange-200 bg-orange-50"
            >
              <img src={~p"/images/logo.svg"} alt="" class="h-5 w-7" />
            </.link>

            <div class="min-w-0 flex-1">
              <p class="truncate text-[11px] font-semibold uppercase text-zinc-500">
                {active_team_name(@sidebar) || "Argus"}
              </p>
              <p class="truncate text-sm font-semibold text-zinc-950">
                {active_project_name(@sidebar) || "Workspace"}
              </p>
            </div>

            <details class="group relative">
              <summary class="flex size-10 list-none cursor-pointer items-center justify-center rounded-[6px] border border-zinc-200 bg-white text-zinc-700 shadow-[0_1px_0_rgba(15,23,42,0.03)] transition hover:border-sky-200 hover:bg-sky-50 hover:text-sky-700 [&::-webkit-details-marker]:hidden">
                <span class="sr-only">Open navigation menu</span>
                <.icon name="hero-bars-3-mini" class="size-5" />
              </summary>

              <div class="absolute right-0 top-full z-50 mt-2 max-h-[70vh] w-[min(21rem,calc(100vw-1.5rem))] overflow-y-auto rounded-[8px] border border-zinc-200 bg-white p-2 shadow-[0_22px_70px_rgba(15,23,42,0.22)] ring-1 ring-zinc-950/5">
                <div :if={@sidebar.teams != []} class="space-y-1">
                  <p class="px-3 py-2 text-[11px] font-semibold uppercase text-zinc-400">Teams</p>
                  <.link
                    :for={team <- @sidebar.teams}
                    navigate={Map.get(@sidebar.team_targets, team.id)}
                    class={[
                      "flex min-h-11 items-center justify-between rounded-[6px] px-3 py-2 text-sm transition",
                      @sidebar.active_team && @sidebar.active_team.id == team.id &&
                        "bg-sky-50 font-semibold text-sky-800",
                      (!@sidebar.active_team || @sidebar.active_team.id != team.id) &&
                        "text-zinc-700 hover:bg-zinc-50"
                    ]}
                  >
                    <span class="truncate">{team.name}</span>
                    <.icon
                      :if={@sidebar.active_team && @sidebar.active_team.id == team.id}
                      name="hero-check-mini"
                      class="size-4 text-sky-600"
                    />
                  </.link>
                </div>

                <div class="mt-2 border-t border-zinc-100 pt-2">
                  <p class="px-3 py-2 text-[11px] font-semibold uppercase text-zinc-400">
                    Projects
                  </p>
                  <div
                    :if={@sidebar.projects == []}
                    class="px-3 py-3 text-sm text-zinc-500"
                  >
                    No projects yet.
                  </div>
                  <.link
                    :for={project <- @sidebar.projects}
                    navigate={~p"/projects/#{project.slug}/issues"}
                    class={[
                      "flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm transition",
                      @sidebar.active_project && @sidebar.active_project.id == project.id &&
                        "bg-zinc-950 font-semibold text-white",
                      (!@sidebar.active_project || @sidebar.active_project.id != project.id) &&
                        "text-zinc-700 hover:bg-zinc-50"
                    ]}
                  >
                    <div class={[
                      "flex size-6 shrink-0 items-center justify-center rounded-[5px] border text-[10px] font-semibold uppercase",
                      project_light_avatar_class(project)
                    ]}>
                      {project_initial(project)}
                    </div>
                    <span class="truncate">{project.name}</span>
                  </.link>
                </div>

                <div class="mt-2 border-t border-zinc-100 pt-2">
                  <.link
                    navigate={~p"/settings"}
                    class="flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm text-zinc-700 transition hover:bg-zinc-50"
                  >
                    <.icon name="hero-cog-6-tooth-mini" class="size-4 text-zinc-500" />
                    <span>Account settings</span>
                  </.link>
                  <.link
                    :if={@current_scope.user.role == :admin}
                    navigate={~p"/admin"}
                    class="flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm text-zinc-700 transition hover:bg-zinc-50"
                  >
                    <.icon name="hero-shield-check-mini" class="size-4 text-zinc-500" />
                    <span>Admin</span>
                  </.link>
                  <.link
                    href={~p"/logout"}
                    method="delete"
                    class="flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm text-zinc-700 transition hover:bg-zinc-50"
                  >
                    <.icon
                      name="hero-arrow-left-start-on-rectangle-mini"
                      class="size-4 text-zinc-500"
                    />
                    <span>Log out</span>
                  </.link>
                </div>
              </div>
            </details>
          </div>
        </header>

        <div class="flex min-h-screen">
          <aside
            id="app-sidebar"
            class="sticky top-0 hidden h-screen w-72 shrink-0 overflow-y-auto border-r border-zinc-900 bg-zinc-950 px-5 py-5 text-zinc-100 lg:flex lg:flex-col"
          >
            <div class="shrink-0 border-b border-zinc-800/90 pb-5">
              <.link
                navigate={ArgusWeb.UserAuth.signed_in_path(@current_scope.user)}
                class="flex items-center gap-3"
              >
                <div class="flex h-9 w-9 items-center justify-center border border-orange-500/25 bg-orange-500/10 text-orange-300">
                  <img src={~p"/images/logo.svg"} alt="" class="h-5 w-7 text-orange-500" />
                </div>
                <div class="space-y-0.5">
                  <p class="text-[11px] font-semibold uppercase tracking-[0.24em] text-zinc-500">
                    Argus
                  </p>
                  <p class="text-sm font-medium text-zinc-100">
                    {active_team_name(@sidebar) || "Overview"}
                  </p>
                </div>
              </.link>
            </div>

            <div :if={length(@sidebar.teams) > 1} class="mt-8 shrink-0 space-y-2.5">
              <p class="text-[10px] font-medium uppercase tracking-[0.22em] text-zinc-600">Teams</p>
              <div class="space-y-1.5">
                <.link
                  :for={team <- @sidebar.teams}
                  navigate={Map.get(@sidebar.team_targets, team.id)}
                  class={[
                    "flex items-center justify-between border-l-2 px-3 py-2.5 text-sm transition",
                    @sidebar.active_team && @sidebar.active_team.id == team.id &&
                      "border-sky-400 bg-zinc-900/90 text-white",
                    @sidebar.active_team && @sidebar.active_team.id != team.id &&
                      "border-transparent text-zinc-400 hover:border-zinc-700 hover:bg-zinc-900/80 hover:text-zinc-100"
                  ]}
                >
                  <span class={[
                    @sidebar.active_team && @sidebar.active_team.id == team.id && "font-medium"
                  ]}>
                    {team.name}
                  </span>
                  <.icon
                    :if={@sidebar.active_team && @sidebar.active_team.id == team.id}
                    name="hero-check-mini"
                    class="size-4 text-sky-300"
                  />
                </.link>
              </div>
            </div>

            <div class="mt-8 min-h-0 flex-1 space-y-2.5">
              <div :if={@sidebar.active_team} class="space-y-1.5">
                <.link
                  navigate={~p"/projects?team_id=#{@sidebar.active_team.id}"}
                  class={[
                    "flex items-center gap-3 border-l-2 px-3 py-2.5 text-sm transition",
                    is_nil(@sidebar.active_project) &&
                      "border-sky-400 bg-zinc-900/90 font-medium text-white",
                    !is_nil(@sidebar.active_project) &&
                      "border-transparent text-zinc-400 hover:border-zinc-700 hover:bg-zinc-900/80 hover:text-zinc-100"
                  ]}
                >
                  <.icon name="hero-squares-2x2-mini" class="size-4 shrink-0" />
                  <span>Overview</span>
                </.link>
              </div>

              <p class="text-[10px] font-medium uppercase tracking-[0.22em] text-zinc-600">
                Projects
              </p>
              <div
                :if={@sidebar.projects == []}
                class="border border-zinc-800 bg-zinc-900/60 px-3 py-4 text-sm text-zinc-500"
              >
                No projects yet.
              </div>
              <div :if={@sidebar.projects != []} class="space-y-1.5">
                <.link
                  :for={project <- @sidebar.projects}
                  navigate={~p"/projects/#{project.slug}/issues"}
                  class={[
                    "flex items-center gap-3 border-l-2 pl-5 pr-3 py-2.5 text-sm transition",
                    @sidebar.active_project && @sidebar.active_project.id == project.id &&
                      "border-sky-400 bg-zinc-100 font-medium text-zinc-950",
                    (!@sidebar.active_project || @sidebar.active_project.id != project.id) &&
                      "border-transparent text-zinc-400 hover:border-zinc-700 hover:bg-zinc-900/80 hover:text-zinc-100"
                  ]}
                >
                  <div class={[
                    "flex h-5 w-5 shrink-0 items-center justify-center rounded-[4px] border text-[10px] font-semibold uppercase",
                    project_avatar_class(project)
                  ]}>
                    {project_initial(project)}
                  </div>
                  <span class="truncate">{project.name}</span>
                </.link>
              </div>
            </div>

            <div class="mt-7 shrink-0 border-t border-zinc-800 pt-5">
              <details class="group relative">
                <summary class="flex w-full list-none cursor-pointer items-center gap-3 border border-transparent px-2 py-2 text-left transition hover:border-zinc-800 hover:bg-zinc-900 [&::-webkit-details-marker]:hidden">
                  <div class="flex h-10 w-10 items-center justify-center bg-zinc-800 text-sm font-semibold uppercase text-zinc-100">
                    {String.first(@current_scope.user.name || @current_scope.user.email)}
                  </div>
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-sm font-medium text-zinc-50">
                      {@current_scope.user.name}
                    </p>
                    <p class="truncate text-xs text-zinc-500">{@current_scope.user.email}</p>
                  </div>
                  <.icon
                    name="hero-chevron-up-down-mini"
                    class="size-4 shrink-0 text-zinc-500 transition group-open:text-zinc-300"
                  />
                </summary>

                <div class="absolute bottom-full left-0 z-30 mb-3 w-60 border border-zinc-800 bg-zinc-950 p-1.5 shadow-[0_18px_48px_rgba(15,23,42,0.35)]">
                  <.link
                    navigate={~p"/settings"}
                    class="flex items-center gap-3 px-3 py-2 text-sm text-zinc-300 transition hover:bg-zinc-900 hover:text-white"
                  >
                    <.icon name="hero-cog-6-tooth-mini" class="size-4 shrink-0 text-zinc-500" />
                    <span>Settings</span>
                  </.link>
                  <.link
                    :if={@current_scope.user.role == :admin}
                    navigate={~p"/admin"}
                    class="flex items-center gap-3 px-3 py-2 text-sm text-zinc-300 transition hover:bg-zinc-900 hover:text-white"
                  >
                    <.icon name="hero-shield-check-mini" class="size-4 shrink-0 text-zinc-500" />
                    <span>Admin</span>
                  </.link>
                  <.link
                    href={~p"/logout"}
                    method="delete"
                    class="flex items-center gap-3 px-3 py-2 text-sm text-zinc-300 transition hover:bg-zinc-900 hover:text-white"
                  >
                    <.icon
                      name="hero-arrow-left-start-on-rectangle-mini"
                      class="size-4 shrink-0 text-zinc-500"
                    />
                    <span>Log out</span>
                  </.link>
                </div>
              </details>
            </div>
          </aside>

          <main class="min-w-0 flex-1 bg-[#e8eaed] px-3 py-4 pb-[calc(5.75rem+env(safe-area-inset-bottom))] sm:px-5 lg:px-8 lg:py-8">
            <div class="w-full min-w-0 space-y-5 lg:space-y-8">
              {render_slot(@inner_block)}
            </div>
          </main>
        </div>

        <nav
          id="mobile-bottom-nav"
          aria-label="Primary mobile navigation"
          class="fixed inset-x-0 bottom-0 z-40 border-t border-zinc-200 bg-white/95 px-2 pb-[calc(0.45rem+env(safe-area-inset-bottom))] pt-2 shadow-[0_-10px_35px_rgba(15,23,42,0.12)] backdrop-blur lg:hidden"
        >
          <div class="mx-auto grid max-w-md grid-cols-5 gap-1">
            <.mobile_nav_item
              navigate={
                if @sidebar.active_team,
                  do: ~p"/projects?team_id=#{@sidebar.active_team.id}",
                  else: ~p"/projects"
              }
              icon="hero-squares-2x2-mini"
              label="Home"
              active={@sidebar.section == :overview}
            />

            <%= if @sidebar.active_project do %>
              <.mobile_nav_item
                navigate={~p"/projects/#{@sidebar.active_project.slug}/issues"}
                icon="hero-bug-ant-mini"
                label="Issues"
                active={@sidebar.section == :issues}
              />
              <.mobile_nav_item
                navigate={~p"/projects/#{@sidebar.active_project.slug}/logs"}
                icon="hero-document-text-mini"
                label="Logs"
                active={@sidebar.section == :logs}
              />
              <.mobile_nav_item
                navigate={~p"/projects/#{@sidebar.active_project.slug}/metrics"}
                icon="hero-chart-bar-mini"
                label="Metrics"
                active={@sidebar.section == :metrics}
              />
            <% else %>
              <.mobile_nav_item
                navigate={
                  if @sidebar.active_team,
                    do: ~p"/teams/#{@sidebar.active_team.id}/settings?tab=projects",
                    else: ~p"/projects"
                }
                icon="hero-user-group-mini"
                label="Team"
                active={@sidebar.section == :team_settings}
              />
              <.mobile_nav_item
                navigate={~p"/settings"}
                icon="hero-cog-6-tooth-mini"
                label="Account"
                active={@sidebar.section == :account}
              />
              <.mobile_nav_item
                :if={@current_scope.user.role == :admin}
                navigate={~p"/admin"}
                icon="hero-shield-check-mini"
                label="Admin"
                active={@sidebar.section == :admin}
              />
              <.mobile_nav_item
                :if={@current_scope.user.role != :admin}
                navigate={~p"/projects"}
                icon="hero-command-line-mini"
                label="Projects"
                active={false}
              />
            <% end %>

            <details class="group relative">
              <summary class={[
                "flex min-h-14 list-none cursor-pointer flex-col items-center justify-center gap-1 rounded-[8px] px-1 text-[10px] font-medium transition [&::-webkit-details-marker]:hidden",
                @sidebar.section in [:project_settings, :team_settings, :account, :admin] &&
                  "bg-zinc-950 text-white",
                @sidebar.section not in [:project_settings, :team_settings, :account, :admin] &&
                  "text-zinc-500 hover:bg-zinc-100 hover:text-zinc-950"
              ]}>
                <.icon name="hero-ellipsis-horizontal-mini" class="size-5" />
                <span>More</span>
              </summary>
              <div class="absolute bottom-full right-0 mb-3 w-56 rounded-[8px] border border-zinc-200 bg-white p-1.5 shadow-[0_22px_70px_rgba(15,23,42,0.22)] ring-1 ring-zinc-950/5">
                <.link
                  :if={@sidebar.active_project && Map.get(@sidebar, :can_manage_active_project?)}
                  navigate={~p"/projects/#{@sidebar.active_project.slug}/settings"}
                  class="flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm text-zinc-700 transition hover:bg-zinc-50"
                >
                  <.icon name="hero-adjustments-horizontal-mini" class="size-4 text-zinc-500" />
                  <span>Project settings</span>
                </.link>
                <.link
                  :if={@sidebar.active_team && Map.get(@sidebar, :can_manage_active_team?)}
                  navigate={~p"/teams/#{@sidebar.active_team.id}/settings?tab=projects"}
                  class="flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm text-zinc-700 transition hover:bg-zinc-50"
                >
                  <.icon name="hero-user-group-mini" class="size-4 text-zinc-500" />
                  <span>Team settings</span>
                </.link>
                <.link
                  navigate={~p"/settings"}
                  class="flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm text-zinc-700 transition hover:bg-zinc-50"
                >
                  <.icon name="hero-cog-6-tooth-mini" class="size-4 text-zinc-500" />
                  <span>Account settings</span>
                </.link>
                <.link
                  :if={@current_scope.user.role == :admin}
                  navigate={~p"/admin"}
                  class="flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm text-zinc-700 transition hover:bg-zinc-50"
                >
                  <.icon name="hero-shield-check-mini" class="size-4 text-zinc-500" />
                  <span>Admin</span>
                </.link>
                <.link
                  href={~p"/logout"}
                  method="delete"
                  class="flex min-h-11 items-center gap-3 rounded-[6px] px-3 py-2 text-sm text-zinc-700 transition hover:bg-zinc-50"
                >
                  <.icon
                    name="hero-arrow-left-start-on-rectangle-mini"
                    class="size-4 text-zinc-500"
                  />
                  <span>Log out</span>
                </.link>
              </div>
            </details>
          </div>
        </nav>
      </div>
    <% else %>
      <main class="flex min-h-screen items-center justify-center bg-[#e8eaed] px-6 py-12">
        <div class="w-full max-w-lg">{render_slot(@inner_block)}</div>
      </main>
    <% end %>

    <.flash_group flash={@flash} />
    """
  end

  defp active_team_name(%{active_team: %{name: name}}), do: name
  defp active_team_name(_sidebar), do: nil

  defp active_project_name(%{active_project: %{name: name}}), do: name
  defp active_project_name(_sidebar), do: nil

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  def mobile_nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex min-h-14 flex-col items-center justify-center gap-1 rounded-[8px] px-1 text-[10px] font-medium transition",
        @active && "bg-zinc-950 text-white",
        !@active && "text-zinc-500 hover:bg-zinc-100 hover:text-zinc-950"
      ]}
    >
      <.icon name={@icon} class="size-5" />
      <span class="max-w-full truncate">{@label}</span>
    </.link>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="pointer-events-none fixed right-4 top-4 z-50 flex w-full max-w-sm flex-col gap-3"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Connection lost")}
        phx-disconnected={show("#client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong")}
        phx-disconnected={show("#server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>

      <div id="client-toasts" phx-hook="ToastViewport" phx-update="ignore"></div>
    </div>
    """
  end
end
