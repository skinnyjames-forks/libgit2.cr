require "./spec_helper"

describe Git::Reference do
  it "should validate ref name" do
    valid = "refs/foobar"
    invalid = "refs/~nope^*"

    Git::Reference.valid_name?(valid).should be_true
    Git::Reference.valid_name?(invalid).should be_false
  end

  it "each can handle exceptions" do
    expect_raises(Exception) do
      FixtureRepo.from_libgit2("testrepo.git") do |repo|
        repo.refs.each do
          raise Exception.new("fail")
        end
      end
    end
  end

  it "should get references list" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      repo.refs.each.map(&.name).to_a.sort.should eq([
        "refs/heads/br2",
        "refs/heads/dir",
        "refs/heads/executable",
        "refs/heads/ident",
        "refs/heads/long-file-name",
        "refs/heads/master",
        "refs/heads/merge-conflict",
        "refs/heads/packed",
        "refs/heads/packed-test",
        "refs/heads/subtrees",
        "refs/heads/test",
        "refs/heads/testrepo-worktree",
        "refs/tags/e90810b",
        "refs/tags/foo/bar",
        "refs/tags/foo/foo/bar",
        "refs/tags/packed-tag",
        "refs/tags/point_to_blob",
        "refs/tags/test",
      ])
    end
  end

  it "can filter refs with glob" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      repo.refs("refs/tags/*").map(&.name).to_a.sort.should eq([
        "refs/tags/e90810b",
        "refs/tags/foo/bar",
        "refs/tags/foo/foo/bar",
        "refs/tags/packed-tag",
        "refs/tags/point_to_blob",
        "refs/tags/test",
      ])
    end
  end

  it "can open reference" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      ref = repo.refs["refs/heads/master"]
      ref.target_id
      ref.type.should eq(Git::RefType::Oid)
      ref.name.should eq("refs/heads/master")
      ref.canonical_name.should eq("refs/heads/master")
      ref.peel.should be_nil
    end
  end

  it "can open a symbolic reference" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      ref = repo.references["HEAD"]
      ref.target_id.should eq("refs/heads/master")
      ref.type.should eq(Git::RefType::Symbolic)

      resolved = ref.resolve
      resolved.type.should eq(Git::RefType::Oid)
      resolved.target_id.to_s.should eq("099fabac3a9ea935598528c27f866e34089c2eff")
      ref.peel.should eq(resolved.target_id)
    end
  end

  it "looking up missing ref returns nil" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      ref = repo.references["lol/wut"]?
      ref.should be_nil
    end
  end

  it "reference exists" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      repo.references.exists?("refs/heads/master").should be_true
      repo.references.exists?("lol/wut").should be_false
    end
  end

  it "test_load_packed_ref" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      ref = repo.references["refs/heads/packed"]
      ref.target_id.to_s.should eq("41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9")
      ref.type.should eq(Git::RefType::Oid)
      ref.name.should eq("refs/heads/packed")
    end
  end

  it "test_resolve_head" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      ref = repo.references["HEAD"]
      ref.target_id.should eq("refs/heads/master")
      ref.type.should eq(Git::RefType::Symbolic)

      head = ref.resolve
      head.target_id.to_s.should eq ("099fabac3a9ea935598528c27f866e34089c2eff")
      head.type.should eq(Git::RefType::Oid)
    end
  end

  it "test_reference_to_tag" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      ref = repo.references["refs/tags/test"]

      ref.target_id.to_s.should eq("b25fa35b38051e4ae45d4222e795f9df2e43f1d1")
      ref.peel.to_s.should eq("e90810b8df3e80c413d903f631643c716887138d")
    end
  end

  it "test_reference_is_branch" do
    repo = FixtureRepo.from_libgit2("testrepo.git")

    repo.references["refs/heads/master"].branch?.should be_true

    repo.references["refs/remotes/test/master"].branch?.should be_false
    repo.references["refs/tags/test"].branch?.should be_false
  end

  it "test_reference_is_remote" do
    repo = FixtureRepo.from_libgit2("testrepo.git")

    repo.references["refs/remotes/test/master"].remote?.should be_true

    repo.references["refs/heads/master"].remote?.should be_false
    repo.references["refs/tags/test"].remote?.should be_false
  end

  it "test_reference_is_tag" do
    repo = FixtureRepo.from_libgit2("testrepo.git")

    repo.references["refs/tags/test"].tag?.should be_true

    repo.references["refs/heads/master"].tag?.should be_false
    repo.references["refs/remotes/test/master"].tag?.should be_false
  end

  describe "write" do
    it "create force" do
      repo = FixtureRepo.from_rugged("testrepo.git")
      master = repo.references["refs/heads/master"].target_id.as(Git::Oid)

      ref = repo.references.create("refs/heads/unit_test", master)
      ref.name.should eq("refs/heads/unit_test")
      expect_raises(Git::Error) do
        repo.references.create("refs/heads/unit_test", master)
      end
      ref = repo.references.create("refs/heads/unit_test", master, true)
      ref.name.should eq("refs/heads/unit_test")
    end

    it "create symbolic ref" do
      repo = FixtureRepo.from_rugged("testrepo.git")

      ref = repo.references.create("refs/heads/unit_test", "refs/heads/master")
      ref.type.should eq(Git::RefType::Symbolic)
      ref.target_id.should eq("refs/heads/master")
      ref.name.should eq("refs/heads/unit_test")
    end

    it "create oid ref" do
      repo = FixtureRepo.from_rugged("testrepo.git")
      id = "36060c58702ed4c2a40832c51758d5344201d89a"
      oid = Git::Oid.new(id)

      ref = repo.references.create("refs/heads/unit_test", oid)
      ref.type.should eq(Git::RefType::Oid)
      ref.target_id.should eq(oid)
      ref.name.should eq("refs/heads/unit_test")

      ref = repo.references.create("refs/heads/unit_test", id, true)
      ref.type.should eq(Git::RefType::Oid)
      ref.target_id.should eq(oid)
      ref.name.should eq("refs/heads/unit_test")
    end
  end

  describe "reflog" do
    it "has?" do
      repo = FixtureRepo.from_libgit2("testrepo")
      ref = repo.references.create("refs/heads/test-reflog-default",
        "a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
      ref.log?.should be_true
    end

    it "default" do
      repo = FixtureRepo.from_libgit2("testrepo")
      ref = repo.references.create("refs/heads/test-reflog-default",
        "a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
      reflog = ref.log

      reflog.size.should eq(1)

      reflog[0].id_old.should eq(Git::Oid.new("0000000000000000000000000000000000000000"))
      reflog[0].id_new.should eq(Git::Oid.new("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))
      reflog[0].message.should be_nil
      # FIXME need to implement config for repo to test it
      # reflog[0].committer.name.should eq("")
      # reflog[0].committer.email.should eq("")
    end
  end
end
