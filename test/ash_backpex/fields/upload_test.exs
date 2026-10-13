defmodule AshBackpex.Fields.UploadTest do
  use AshBackpex.DataCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias AshBackpex.TestDomain.Document

  @endpoint AshBackpex.TestEndpoint

  setup_all do
    start_supervised!({Phoenix.PubSub, name: AshBackpex.TestPubSub})
    start_supervised!(AshBackpex.TestEndpoint)
    :ok
  end

  setup do
    File.rm_rf!(TestDocumentUploadLive.upload_dir())
    on_exit(fn -> File.rm_rf!(TestDocumentUploadLive.upload_dir()) end)
    :ok
  end

  test "passes the upload options through to Backpex.Fields.Upload" do
    file = TestDocumentUploadLive.fields()[:file]

    assert file.module == Backpex.Fields.Upload
    assert file.upload_key == :file
    assert file.accept == ~w(.txt)
    assert file.max_entries == 1
    assert file.max_file_size == 1_000
    assert file.list_existing_files == (&TestDocumentUploadLive.list_existing_files/1)
    assert file.file_label == (&TestDocumentUploadLive.file_label/1)
    assert file.put_upload_change == (&TestDocumentUploadLive.put_upload_change/6)
    assert file.consume_upload == (&TestDocumentUploadLive.consume_upload/4)
    assert file.remove_uploads == (&TestDocumentUploadLive.remove_uploads/3)
  end

  test "leaves the upload options off fields that do not set them" do
    title = TestDocumentUploadLive.fields()[:title]

    for key <- [:upload_key, :accept, :max_entries, :max_file_size, :consume_upload] do
      refute Map.has_key?(title, key)
    end
  end

  test "creates a record with an uploaded file and consumes the upload" do
    {:ok, view, _html} = live(conn(), "/documents/new")

    upload =
      file_input(view, "#resource-form", :file, [
        %{name: "notes.txt", content: "hello", type: "text/plain"}
      ])

    assert render_upload(upload, "notes.txt") =~ "notes.txt"

    assert {:error, {:live_redirect, %{to: "/documents"}}} =
             view
             |> form("#resource-form", change: %{title: "Release notes"})
             |> render_submit(%{"save-type" => "save"})

    assert [%{title: "Release notes", file: "notes.txt"}] = Ash.read!(Document)
    assert File.read!(Path.join(TestDocumentUploadLive.upload_dir(), "notes.txt")) == "hello"
  end

  test "removes an existing file on edit" do
    File.mkdir_p!(TestDocumentUploadLive.upload_dir())
    File.write!(Path.join(TestDocumentUploadLive.upload_dir(), "old.txt"), "old")

    document =
      Document
      |> Ash.Changeset.for_create(:create, %{title: "Old notes", file: "old.txt"})
      |> Ash.create!()

    {:ok, view, html} = live(conn(), "/documents/#{document.id}/edit")

    assert html =~ "uploaded old.txt"

    view
    |> element("[phx-click='cancel-existing-entry'][phx-value-ref='old.txt']")
    |> render_click()

    assert {:error, {:live_redirect, %{to: "/documents"}}} =
             view
             |> form("#resource-form")
             |> render_submit(%{"save-type" => "save"})

    assert Ash.get!(Document, document.id).file == nil
    refute File.exists?(Path.join(TestDocumentUploadLive.upload_dir(), "old.txt"))
  end

  describe "a list of uploads" do
    test "creates a record with several uploaded files" do
      {:ok, view, _html} = live(conn(), "/document-attachments/new")

      upload =
        file_input(view, "#resource-form", :attachments, [
          %{name: "one.txt", content: "one", type: "text/plain"},
          %{name: "two.txt", content: "two", type: "text/plain"}
        ])

      render_upload(upload, "one.txt")
      render_upload(upload, "two.txt")

      assert {:error, {:live_redirect, %{to: "/document-attachments"}}} =
               view
               |> form("#resource-form", change: %{title: "Minutes"})
               |> render_submit(%{"save-type" => "save"})

      assert [%{attachments: attachments}] = Ash.read!(Document)
      assert Enum.sort(attachments) == ["one.txt", "two.txt"]
      assert File.read!(upload_path("one.txt")) == "one"
      assert File.read!(upload_path("two.txt")) == "two"
    end

    test "keeps a validation error and the staged files, then saves them" do
      {:ok, view, _html} = live(conn(), "/document-attachments/new")

      upload =
        file_input(view, "#resource-form", :attachments, [
          %{name: "one.txt", content: "one", type: "text/plain"},
          %{name: "two.txt", content: "two", type: "text/plain"}
        ])

      render_upload(upload, "one.txt")
      render_upload(upload, "two.txt")

      html =
        view
        |> form("#resource-form", change: %{title: ""})
        |> render_submit(%{"save-type" => "save"})

      assert html =~ "There are errors in the form."
      assert html =~ "one.txt"
      assert html =~ "two.txt"
      assert Ash.read!(Document) == []

      assert {:error, {:live_redirect, %{to: "/document-attachments"}}} =
               view
               |> form("#resource-form", change: %{title: "Minutes"})
               |> render_submit(%{"save-type" => "save"})

      assert [%{attachments: attachments}] = Ash.read!(Document)
      assert Enum.sort(attachments) == ["one.txt", "two.txt"]
    end

    test "removes one of several existing files on edit" do
      document = document_with_attachments!(["one.txt", "two.txt"])

      {:ok, view, _html} = live(conn(), "/document-attachments/#{document.id}/edit")

      view
      |> element("[phx-click='cancel-existing-entry'][phx-value-ref='one.txt']")
      |> render_click()

      assert {:error, {:live_redirect, %{to: "/document-attachments"}}} =
               view
               |> form("#resource-form")
               |> render_submit(%{"save-type" => "save"})

      assert Ash.get!(Document, document.id).attachments == ["two.txt"]
      refute File.exists?(upload_path("one.txt"))
      assert File.exists?(upload_path("two.txt"))
    end

    test "removes every existing file on edit" do
      document = document_with_attachments!(["one.txt", "two.txt"])

      {:ok, view, _html} = live(conn(), "/document-attachments/#{document.id}/edit")

      for file <- ["one.txt", "two.txt"] do
        view
        |> element("[phx-click='cancel-existing-entry'][phx-value-ref='#{file}']")
        |> render_click()
      end

      assert {:error, {:live_redirect, %{to: "/document-attachments"}}} =
               view
               |> form("#resource-form")
               |> render_submit(%{"save-type" => "save"})

      assert Ash.get!(Document, document.id).attachments == []
      refute File.exists?(upload_path("one.txt"))
      refute File.exists?(upload_path("two.txt"))
    end
  end

  defp document_with_attachments!(files) do
    File.mkdir_p!(TestDocumentUploadLive.upload_dir())
    for file <- files, do: File.write!(upload_path(file), file)

    Document
    |> Ash.Changeset.for_create(:create, %{title: "Minutes", attachments: files})
    |> Ash.create!()
  end

  defp upload_path(file), do: Path.join(TestDocumentUploadLive.upload_dir(), file)

  defp conn, do: init_test_session(build_conn(), %{})
end
