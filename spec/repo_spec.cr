require "./spec_helper"

describe Git::Repo do

  it "should fails to open unexisting repos" do
    expect_raises(Exception) do
      Git::Repository.open("fakepath/123/")
    end

    expect_raises(Exception) do
      Git::Repository.open("test")
    end
  end

  it "#last_commit" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      repo.last_commit.target_id.to_s.should eq "a65fedf39aefe402d3bb6e24df4d4f5fe4547750"
    end
  end

  it "can check if objects exist" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      repo.exists?("8496071c1b46c854b31185ea97743be6a8774479").should be_true
      repo.exists?("1385f264afb75a56a5bec74243be9b367ba4ca08").should be_true
      repo.exists?("ce08fe4884650f067bd5703b6a59a8b3b3c99a09").should be_false
      repo.exists?("8496071c1c46c854b31185ea97743be6a8774479").should be_false
    end
  end

  # test_can_read_a_raw_object
  # test_can_read_object_headers
  # test_check_reads_fail_on_missing_objects
  # test_check_read_headers_fail_on_missing_objects

  it "should walking with block" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      oid = "a4a7dce85cf63874e984719f4fdd239f5145052f"
      list = [] of Git::Commit
      repo.walk(oid) { |c| list << c }
      actual = list.map { |c| c.sha[0, 5] }.join('.')

      actual.should eq "a4a7d.c4780.9fd73.4a202.5b5b0.84960"
    end
  end

  it "should walking without block" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      commits = repo.walk("a4a7dce85cf63874e984719f4fdd239f5145052f")
      commits.should be_a(Enumerable(Git::Commit))
      commits.size.should be > 0
    end
  end

  it "should lookup object" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      object = repo.lookup("8496071c1b46c854b31185ea97743be6a8774479")
      object.should be_a(Git::Commit)
    end
  end

  it "should find reference" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      ref = repo.ref("refs/heads/master")
      ref.should be_a(Git::Reference)
      ref.name.should eq("refs/heads/master")
    end
  end

  it "should match all refs" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      refs = repo.refs("refs/heads/*")
      refs.size.should eq(12)
    end
  end

  it "should return all ref names" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      refs = repo.ref_names
      ref_names = refs.to_a
      ref_names.should eq([
        "refs/heads/br2",
        "refs/heads/cannot-fetch",
        "refs/heads/chomped",
        "refs/heads/haacked",
        "refs/heads/master",
        "refs/heads/not-good",
        "refs/heads/packed-test",
        "refs/heads/subtrees",
        "refs/heads/test",
        "refs/heads/track-local",
        "refs/heads/trailing",
        "refs/notes/fanout",
        "refs/remotes/test/master",
        "refs/tags/annotated_tag_to_blob",
        "refs/tags/e90810b",
        "refs/tags/hard_tag",
        "refs/tags/point_to_blob",
        "refs/tags/taggerless",
        "refs/tags/test",
        "refs/tags/wrapped_tag",
        "refs/heads/packed",
      ])
    end
  end

  it "should return all tags" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      tags = repo.tags
      tag_names = tags.map {|tag| tag.name}
      tag_names.should eq([
        "annotated_tag_to_blob",
        "e90810b",
        "hard_tag",
        "point_to_blob",
        "taggerless",
        "test",
        "wrapped_tag"
      ])
    end
  end

  it "should return matching tags" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      repo.tags("e90810b").size.should eq(1)
      repo.tags("*tag*").size.should eq(4)
    end
  end

  pending "should return all remotes" do
    FixtureRepo.from_libgit2("testrepo.git") do |repo|
      remotes = repo.remotes
      remotes.size.should eq(5)
    end
  end

  it "should return workdir" do
    repo = FixtureRepo.from_libgit2("testrepo")
    repo.workdir.should contain("rugged-libgit2-testrepo/")
  end

  it "should return attributes" do
    attributes = "
*.txt linguist-lang=text
new.txt other-attr=this
README is_readme
"

    repo = FixtureRepo.from_libgit2("testrepo")
    # repo.checkout_tree("refs/heads/dir")
    File.write(File.join(repo.workdir, ".gitattributes"), attributes)

    attrs = repo.attributes("new.txt")
    attrs["linguist-lang"].should eq("text")
    attrs["other-attr"].should eq("this")
  end
end
