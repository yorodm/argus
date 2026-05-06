defmodule Argus.Projects.IssueActionWebhookTest do
  use Argus.DataCase, async: false

  alias Argus.Projects
  alias Argus.Projects.IssueNotifier

  import Argus.AccountsFixtures
  import Argus.WorkspaceFixtures

  setup do
    previous_config = Application.get_env(:argus, IssueNotifier, [])

    Application.put_env(:argus, IssueNotifier,
      req_options: [plug: {Req.Test, Argus.IssueWebhookStub}]
    )

    on_exit(fn ->
      Application.put_env(:argus, IssueNotifier, previous_config || [])
    end)

    :ok
  end

  test "sends assignment and unassignment webhooks with actor and assignee names" do
    %{user: actor, team: team, project: project} = workspace_fixture()
    assignee = user_fixture(%{name: "Casey Operator"})
    membership_fixture(team, assignee)
    issue = issue_fixture(project)

    _project = configure_webhook!(project)

    test_pid = self()

    Req.Test.stub(Argus.IssueWebhookStub, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:webhook_request, Jason.decode!(body)})
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, assigned_issue} = Projects.assign_error_event(actor, issue, assignee.id)

    assert_receive {:webhook_request, assigned_payload}
    assert assigned_payload["event"] == "issue_assigned"
    assert assigned_payload["text"] == "#{actor.name} assigned this issue to #{assignee.name}"
    assert assigned_payload["actor_name"] == actor.name
    assert assigned_payload["target_name"] == assignee.name
    assert assigned_payload["assignee_name"] == assignee.name
    assert assigned_payload["assignment_change"]["from"] == nil
    assert assigned_payload["assignment_change"]["to"]["name"] == assignee.name

    assert {:ok, _unassigned_issue} = Projects.unassign_error_event(actor, assigned_issue)

    assert_receive {:webhook_request, unassigned_payload}
    assert unassigned_payload["event"] == "issue_unassigned"

    assert unassigned_payload["text"] ==
             "#{actor.name} unassigned #{assignee.name} from this issue"

    assert unassigned_payload["actor_name"] == actor.name
    assert unassigned_payload["target_name"] == assignee.name
    assert unassigned_payload["assignee_name"] == nil
    assert unassigned_payload["assignment_change"]["from"]["name"] == assignee.name
    assert unassigned_payload["assignment_change"]["to"] == nil
  end

  test "sends status webhooks with actor names and status changes" do
    %{user: actor, project: project} = workspace_fixture()
    issue = issue_fixture(project)

    _project = configure_webhook!(project)

    test_pid = self()

    Req.Test.stub(Argus.IssueWebhookStub, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:webhook_request, Jason.decode!(body)})
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, resolved_issue} = Projects.update_error_event_status(actor, issue, :resolved)

    assert_receive {:webhook_request, resolved_payload}
    assert resolved_payload["event"] == "issue_resolved"
    assert resolved_payload["text"] == "#{actor.name} marked this issue as resolved"
    assert resolved_payload["actor_name"] == actor.name
    assert resolved_payload["status_change"] == %{"from" => "unresolved", "to" => "resolved"}

    assert {:ok, reopened_issue} =
             Projects.update_error_event_status(actor, resolved_issue, :unresolved)

    assert_receive {:webhook_request, reopened_payload}
    assert reopened_payload["event"] == "issue_reopened"
    assert reopened_payload["text"] == "#{actor.name} reopened this issue"
    assert reopened_payload["actor_name"] == actor.name
    assert reopened_payload["status_change"] == %{"from" => "resolved", "to" => "unresolved"}

    assert {:ok, _ignored_issue} =
             Projects.update_error_event_status(actor, reopened_issue, :ignored)

    assert_receive {:webhook_request, ignored_payload}
    assert ignored_payload["event"] == "issue_ignored"
    assert ignored_payload["text"] == "#{actor.name} marked this issue as ignored"
    assert ignored_payload["actor_name"] == actor.name
    assert ignored_payload["status_change"] == %{"from" => "unresolved", "to" => "ignored"}
  end

  test "does not send user action webhooks for no-op or invalid changes" do
    %{user: actor, project: project} = workspace_fixture()
    outsider = user_fixture()
    issue = issue_fixture(project)

    _project = configure_webhook!(project)

    test_pid = self()

    Req.Test.stub(Argus.IssueWebhookStub, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:unexpected_webhook_request, Jason.decode!(body)})
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, _issue} = Projects.update_error_event_status(actor, issue, :unresolved)
    assert {:error, :invalid_assignee} = Projects.assign_error_event(actor, issue, outsider.id)

    refute_receive {:unexpected_webhook_request, _payload}
  end

  defp configure_webhook!(project) do
    {:ok, project} =
      Projects.update_project_webhook(project, %{
        "webhook_url" => "https://hooks.argus.test/issues",
        "webhook_body_template" => ~s({
            "text": "{{event_label}}",
            "event": "{{event}}",
            "actor_name": "{{actor.name}}",
            "target_name": "{{target_user.name}}",
            "assignee_name": "{{assignee.name}}",
            "status_change": "{{status_change}}",
            "assignment_change": "{{assignment_change}}"
          })
      })

    project
  end
end
