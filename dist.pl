use strict;
use warnings;
use 5.38.2;

use File::Copy qw(copy);
use File::Copy::Recursive qw(dircopy);
use File::Spec::Functions qw(catfile);
use Term::ANSIColor qw(colored);

use Time::Piece;

my $main_file = "EmojiLookup.exe";

unless (-f $main_file) {
  say colored("Missing $main_file!", "bright_red");
  exit 1
}

my @files = (
  $main_file,

  "LICENSE",
  "LICENSE-Unicode.txt",
  "readme.md"
);

my $date_str = localtime->strftime("%d.%m.%Y");
my $build_dir = catfile("builds", $date_str."_test");

mkdir $build_dir unless -d $build_dir;

for my $file (@files) {
  copy $file, $build_dir or warn "Couldn't copy $file, skipping..."
}

dircopy "data", "$build_dir/data";
say "Copied Unicode emoji data";

rename "dist/LICENSE", "dist/LICENSE.TXT";
say "Renamed LICENSE.txt"
