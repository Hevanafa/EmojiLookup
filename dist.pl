use strict;
use warnings;
use 5.38.2;

use File::Copy qw(copy);
use File::Copy::Recursive qw(dircopy);

my @files = (
  "EmojiLookup.exe",
  "LICENSE",
  "LICENSE-Unicode.txt"
);

mkdir "dist" unless -d "dist";

for my $file (@files) {
  copy $file, "dist"
}

dircopy "data", "dist/data";
say "Copied Unicode emoji data";

rename "dist/LICENSE", "dist/LICENSE.TXT"
say "Renamed LICENSE.txt"
