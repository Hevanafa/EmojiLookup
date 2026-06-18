use strict;
use warnings;
use 5.38.2;

use File::Copy qw(copy);
use File::Copy::Recursive qw(dircopy);
use File::Spec::Functions qw(catfile);

use Time::Piece;

my @files = (
  "EmojiLookup.exe",

  "LICENSE",
  "LICENSE-Unicode.txt",
  "readme.md"
);

my $date_str = localtime->strftime("%d.%m.%Y");
my $build_dir = catfile("builds", $date_str."_test");

mkdir $build_dir unless -d $build_dir;

for my $file (@files) {
  copy $file, $build_dir
}

dircopy "data", "$build_dir/data";
say "Copied Unicode emoji data";

rename "dist/LICENSE", "dist/LICENSE.TXT";
say "Renamed LICENSE.txt"
