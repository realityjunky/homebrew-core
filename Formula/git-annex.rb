require "language/haskell"

class GitAnnex < Formula
  include Language::Haskell::Cabal

  desc "Manage files with git without checking in file contents"
  homepage "https://git-annex.branchable.com/"
  url "https://hackage.haskell.org/package/git-annex-6.20160907/git-annex-6.20160907.tar.gz"
  sha256 "6714156245c35647d7ac4b9b0c786c74584aa5ecef2fc0aa32044a3a6e722ef7"
  head "git://git-annex.branchable.com/"

  bottle do
    cellar :any
    sha256 "b2f80538962f6b434e696039abcd2c7d1ad09eb7bb7b763ec996098a8c78057b" => :el_capitan
    sha256 "888c92bcc9a04f17b95e57ee8dd864b48a07c9fbe53bc127139483c382dcd8a2" => :yosemite
    sha256 "d72bc1e11a28c725e18cdc74996a4250ae981572d4e7ea0ab42c0fa78b7ec952" => :mavericks
  end

  option "with-git-union-merge", "Build the git-union-merge tool"

  depends_on "ghc" => :build
  depends_on "cabal-install" => :build
  depends_on "pkg-config" => :build
  depends_on "gsasl"
  depends_on "libidn"
  depends_on "libmagic"
  depends_on "gnutls"
  depends_on "quvi"

  def install
    # Fixes CI timeout by providing a more specific hint for Solver
    # Reported 9 Aug 2016: https://github.com/joeyh/git-annex/pull/56
    # Can be removed once prowdsponsor/esqueleto#137 is resolved
    inreplace "git-annex.cabal", "persistent (< 2.5)", "persistent (== 2.2.4.1)"

    install_cabal_package :using => ["alex", "happy", "c2hs"], :flags => ["s3", "webapp"] do
      # this can be made the default behavior again once git-union-merge builds properly when bottling
      if build.with? "git-union-merge"
        system "make", "git-union-merge", "PREFIX=#{prefix}"
        bin.install "git-union-merge"
        system "make", "git-union-merge.1", "PREFIX=#{prefix}"
      end
    end
    bin.install_symlink "git-annex" => "git-annex-shell"
  end

  test do
    # make sure git can find git-annex
    ENV.prepend_path "PATH", bin
    # We don't want this here or it gets "caught" by git-annex.
    rm_r "Library/Python/2.7/lib/python/site-packages/homebrew.pth"

    system "git", "init"
    system "git", "annex", "init"
    (testpath/"Hello.txt").write "Hello!"
    assert !File.symlink?("Hello.txt")
    assert_match "add Hello.txt ok", shell_output("git annex add .")
    system "git", "commit", "-a", "-m", "Initial Commit"
    assert File.symlink?("Hello.txt")

    # The steps below are necessary to ensure the directory cleanly deletes.
    # git-annex guards files in a way that isn't entirely friendly of automatically
    # wiping temporary directories in the way `brew test` does at end of execution.
    system "git", "rm", "Hello.txt", "-f"
    system "git", "commit", "-a", "-m", "Farewell!"
    system "git", "annex", "unused"
    assert_match "dropunused 1 ok", shell_output("git annex dropunused 1 --force")
    system "git", "annex", "uninit"
  end
end
