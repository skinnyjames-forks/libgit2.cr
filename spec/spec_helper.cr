require "spec"
require "file_utils"
require "../src/git"

module FixtureRepo
  TEST_DIR            = __DIR__
  LIBGIT2_FIXTURE_DIR = File.join(FixtureRepo::TEST_DIR, "libgit2", "tests", "resources")

  # Create a new, empty repository.
  def self.empty(*args)
    path = mktmpdir("rugged-empty")
    ensure_cleanup(path)
    Git::Repository.init_at(path, *args)
  end

  # Create a repository based on a rugged fixture repo.
  def self.from_rugged(name)
    path = mktmpdir("rugged-#{name}")
    ensure_cleanup(path)

    FileUtils.cp_r(File.join(FixtureRepo::TEST_DIR, "rugged", "test", "fixtures", name, "."), path)

    prepare(path)

    Git::Repository.open(path)
  end

  def self.from_rugged(name, &block)
    yield from_rugged(name)
  end

  # Create a repository based on a libgit2 fixture repo.
  def self.from_libgit2(name, *args)
    path = mktmpdir("rugged-libgit2-#{name}")
    ensure_cleanup(path)

    FileUtils.cp_r(File.join(FixtureRepo::LIBGIT2_FIXTURE_DIR, name, "."), path)

    prepare(path)

    Git::Repository.open(path)
  end

  def self.from_libgit2(name, *args, &block)
    yield from_libgit2(name, *args)
  end

  def self.mktmpdir(name)
    File.tempname("-#{name}")
  end

  def self.ensure_cleanup(path)
    Spec.after_suite { FileUtils.rm_rf(path) }
  end

  def self.prepare(path)
    FileUtils.cd(path) do
      File.rename(".gitted", ".git") if File.exists?(".gitted")
      File.rename("gitattributes", ".gitattributes") if File.exists?("gitattributes")
      File.rename("gitignore", ".gitignore") if File.exists?("gitignore")
    end
  end

  def self.clone(repository)
    path = mktmpdir("rugged")
    ensure_cleanup(path)

    `git clone --quiet -- #{repository.path} #{path}`

    Git::Repository.open(path)
  end

  def self.clone_from_rugged(repo_name, &block)
    source_repo = from_rugged(repo_name)
    yield clone(source_repo)
  end

  def self.lookup_from_rugged_repo(repo_name, oid, &block)
    repo = from_rugged(repo_name)
    commit = repo.lookup_commit(oid)
    yield commit, repo
  end

  def self.lookup_tree_from_rugged_clone(repo_name, oid, &block)
    repo = from_rugged(repo_name)
    cloned = clone(repo)
    yield(cloned.lookup_tree(oid), cloned)
  end
end
